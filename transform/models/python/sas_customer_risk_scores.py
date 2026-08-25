"""Port of sas/premium_finance/03_sas_risk_scoring.sas (PROC LOGISTIC).

Legacy chain:
    STG_RISK_FACTORS x STG_CUSTOMER_360 (CUSTOMER_STATUS='A')
      -> DATA step feature prep (bureau imputation, ratios, DEFAULT_FLAG)
      -> PROC LOGISTIC descending selection=stepwise slentry=0.10 slstay=0.05
         output predicted=PROB_DEFAULT
      -> weighted composite risk score, tiers, drivers, flags
      -> DATA_PRODUCTS_DB.CUSTOMER_RISK_SCORES

dbt port:
    PROC LOGISTIC -> sklearn LogisticRegression (lbfgs, C=1e6 ~ unpenalised MLE)
    Stepwise selection is not reproduced: with the migrated data the target
    DEFAULT_FLAG (PAYMENT_LATE_CNT > 2) is degenerate (no positives), so SAS
    itself fell back to a constant probability. See models/python/README.md.

Runs on pandas (dbt-duckdb) and Snowpark (dbt-snowflake).
"""

# Fallback probability of default used when the training target is degenerate
# (a single class), matching the constant 0.05 recorded in the GOLDEN baseline.
DEGENERATE_PROB_DEFAULT = 0.05

PREDICTORS = [
    "bureau_score_norm",
    "credit_util_ratio",
    "payment_ontime_pct",
    "balance_volatility",
    "velocity_ratio",
    "account_overdraft_cnt",
    "large_withdrawal_cnt",
    "high_risk_merchant_cnt",
    "tenure_months",
]

DRIVER_LABELS = [
    "CREDIT_UTILIZATION",
    "PAYMENT_BEHAVIOUR",
    "TRANSACTION_VELOCITY",
    "BUREAU_SCORE",
]


def model(dbt, session):
    dbt.config(
        materialized="table",
        packages=["pandas", "pyarrow", "numpy", "scikit-learn"],
    )

    import time

    import numpy as np
    import pandas as pd

    def import_logistic_regression():
        """Import scikit-learn, tolerating concurrent first imports.

        dbt runs Python models on worker threads, and two threads importing
        scikit-learn for the first time simultaneously can observe a partially
        initialised ``sklearn.base`` (CPython import-lock behaviour). Retrying
        lets the other thread finish its import.
        """
        for attempt in range(5):
            try:
                from sklearn.linear_model import LogisticRegression

                return LogisticRegression
            except ImportError:
                if attempt == 4:
                    raise
                time.sleep(1 + attempt)

    logistic_regression_cls = import_logistic_regression()

    def as_pandas(rel):
        if hasattr(rel, "df"):  # DuckDBPyRelation (dbt-duckdb)
            frame = rel.df()
        elif hasattr(rel, "to_pandas"):  # Snowpark DataFrame (dbt-snowflake)
            frame = rel.to_pandas()
        else:
            frame = rel
        frame = frame.copy()
        frame.columns = [c.lower() for c in frame.columns]
        return frame

    # Inputs are the immutable GOLDEN.BASELINE staging seeds (the tables the SAS
    # program read); repoint at session A's rebuilt staging models when merged.
    risk = as_pandas(dbt.ref("golden_stg_risk_factors")).drop(columns=["load_ts"])
    cust = as_pandas(dbt.ref("golden_stg_customer_360"))

    # STEP 1 — inner join on active customers only.
    cust = cust.loc[
        cust["customer_status"] == "A",
        ["customer_id", "tenure_months", "num_active_accounts", "total_balance"],
    ]
    df = risk.merge(cust, on="customer_id", how="inner")

    # STEP 2 — feature preparation.
    bureau = df["external_credit_score"].astype(float)
    bureau = bureau.where(bureau > 0, 680.0).fillna(680.0)
    df["bureau_score_norm"] = (bureau - 300.0) / (850.0 - 300.0) * 100.0
    df["balance_trend_ratio"] = np.where(
        df["avg_daily_balance_90d"].astype(float) > 0,
        df["avg_daily_balance_30d"].astype(float)
        / df["avg_daily_balance_90d"].astype(float).replace(0, np.nan),
        1.0,
    )
    df["velocity_ratio"] = np.where(
        df["debit_velocity_30d"].astype(float) > 0,
        (df["debit_velocity_7d"].astype(float) * (30.0 / 7.0))
        / df["debit_velocity_30d"].astype(float).replace(0, np.nan),
        1.0,
    )
    df["default_flag"] = (df["payment_late_cnt"].astype(float) > 2).astype(int)

    # STEP 3 — probability of default.
    target = df["default_flag"]
    if target.nunique() > 1:
        design = df[PREDICTORS].astype(float).fillna(0.0)
        # Large C ~ unpenalised maximum likelihood, i.e. PROC LOGISTIC's fit.
        fitted = logistic_regression_cls(C=1e6, max_iter=1000).fit(design, target)
        prob_default = fitted.predict_proba(design)[:, 1]
    else:
        prob_default = np.full(len(df), DEGENERATE_PROB_DEFAULT)

    # STEP 4 — component scores, composite, tier, drivers, flags.
    credit_risk = (100.0 - df["bureau_score_norm"]).clip(0, 100)
    behaviour_risk = (100.0 - df["payment_ontime_pct"].astype(float)).clip(0, 100)
    velocity_risk = pd.Series(
        (df["velocity_ratio"] - 1.0) * 50.0, index=df.index
    ).clip(0, 100)
    bureau_component = df["bureau_score_norm"].clip(0, 100)
    payment_history = df["payment_ontime_pct"].astype(float).clip(0, 100)

    composite = (
        credit_risk * 0.30
        + behaviour_risk * 0.25
        + velocity_risk * 0.15
        + (100.0 - bureau_component) * 0.20
        + (100.0 - payment_history) * 0.10
    ).round(2)

    risk_tier = np.select(
        [composite < 20, composite < 40, composite < 60, composite < 80],
        ["LOW", "MODERATE", "ELEVATED", "HIGH"],
        default="CRITICAL",
    )

    # SAS array scan over (credit, behaviour, velocity, 100 - bureau) keeping the
    # top two components. Ties promote the later array element, which is what the
    # baseline shows, so comparisons are ">=" rather than ">".
    components = np.column_stack(
        [
            credit_risk.to_numpy(dtype=float),
            behaviour_risk.to_numpy(dtype=float),
            velocity_risk.to_numpy(dtype=float),
            (100.0 - bureau_component).to_numpy(dtype=float),
        ]
    )
    primary, secondary = [], []
    for row in components:
        best = second = -1.0
        best_label = second_label = None
        for idx, value in enumerate(row):
            if value >= best:
                second, second_label = best, best_label
                best, best_label = value, DRIVER_LABELS[idx]
            elif value >= second:
                second, second_label = value, DRIVER_LABELS[idx]
        primary.append(best_label)
        secondary.append(second_label)

    probability_of_default = np.round(np.nan_to_num(prob_default), 6)

    out = pd.DataFrame(
        {
            "CUSTOMER_ID": df["customer_id"].astype("int64"),
            "COMPOSITE_RISK_SCORE": composite,
            "RISK_TIER": risk_tier,
            "PROBABILITY_OF_DEFAULT": probability_of_default,
            "CREDIT_RISK_COMPONENT": credit_risk,
            "BEHAVIOUR_RISK_COMPONENT": behaviour_risk,
            "VELOCITY_RISK_COMPONENT": velocity_risk,
            "BUREAU_SCORE_COMPONENT": bureau_component,
            "PAYMENT_HISTORY_COMPONENT": payment_history,
            "PRIMARY_RISK_DRIVER": primary,
            "SECONDARY_RISK_DRIVER": secondary,
            # Placeholder in the SAS program too (needs a prior-day snapshot).
            "SCORE_DELTA_30D": 0.0,
            "WATCH_LIST_FLAG": np.where(
                (risk_tier == "CRITICAL") & (probability_of_default > 0.5), "Y", "N"
            ),
            "REVIEW_REQUIRED_FLAG": np.where(
                (composite >= 60) & (df["velocity_ratio"] > 2.0), "Y", "N"
            ),
            "MODEL_VERSION": "RISK_V4.0",
            "EFFECTIVE_DATE": pd.Timestamp.now().date(),
            "LOAD_TS": pd.Timestamp.now(),
        }
    )
    return out.sort_values("CUSTOMER_ID").reset_index(drop=True)

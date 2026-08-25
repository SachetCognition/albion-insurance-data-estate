"""Port of sas/premium_finance/01_sas_customer_segments.sas (PROC FASTCLUS).

Legacy chain:
    ETL_STAGING_DB.STG_CUSTOMER_360  -> feature engineering (DATA step)
                                     -> PROC STDIZE method=std
                                     -> PROC FASTCLUS maxclusters=5 maxiter=50
                                        converge=0.001 least=2
                                     -> label clusters by descending mean
                                        LOG_BALANCE
                                     -> DATA_PRODUCTS_DB.CUSTOMER_SEGMENTS

dbt port:
    PROC STDIZE  -> sklearn StandardScaler (zero mean, unit variance)
    PROC FASTCLUS-> sklearn KMeans(n_clusters=5, max_iter=50, tol=0.001,
                    n_init=10, random_state=42)

Runs on pandas (dbt-duckdb, local) and Snowpark (dbt-snowflake). See
models/python/README.md for the parity tolerance rationale.
"""


def model(dbt, session):
    dbt.config(
        materialized="table",
        packages=["pandas", "pyarrow", "numpy", "scikit-learn"],
    )

    import time

    import numpy as np
    import pandas as pd

    def import_sklearn():
        """Import scikit-learn, tolerating concurrent first imports.

        dbt runs Python models on worker threads, and two threads importing
        scikit-learn for the first time simultaneously can observe a partially
        initialised ``sklearn.base`` (CPython import-lock behaviour). Retrying
        lets the other thread finish its import.
        """
        for attempt in range(5):
            try:
                from sklearn.cluster import KMeans
                from sklearn.preprocessing import StandardScaler

                return KMeans, StandardScaler
            except ImportError:
                if attempt == 4:
                    raise
                time.sleep(1 + attempt)

    kmeans_cls, scaler_cls = import_sklearn()

    # Input is the immutable GOLDEN.BASELINE staging seed (the exact table the
    # SAS program consumed). When session A's rebuilt stg_customer_360 model
    # lands this ref can be repointed at it without touching the logic below.
    src = dbt.ref("golden_stg_customer_360")
    if hasattr(src, "df"):  # DuckDBPyRelation (dbt-duckdb)
        src = src.df()
    elif hasattr(src, "to_pandas"):  # Snowpark DataFrame (dbt-snowflake)
        src = src.to_pandas()
    df = src.copy()
    df.columns = [c.lower() for c in df.columns]

    # STEP 1 — same WHERE clause as the SAS PROC SQL extract.
    df = df[df["customer_status"] == "A"].copy()

    # STEP 2 — feature engineering (SAS DATA step WORK.CUST_FEATURES).
    product_flags = [
        (df[col] == "Y").astype(float)
        for col in ("has_checking", "has_savings", "has_credit", "has_loan")
    ]
    df["product_breadth"] = sum(product_flags) / len(product_flags)
    df["log_balance"] = np.log(df["total_balance"].astype(float).clip(lower=1))
    df["acct_ratio"] = df["num_active_accounts"].astype(float) / df[
        "num_accounts"
    ].astype(float).clip(lower=1)

    # Banding thresholds are inclusive of the upper bound, which is how the
    # GOLDEN baseline was produced (see README.md "Banding boundaries").
    tenure = df["tenure_months"].astype(float)
    df["tenure_group"] = np.select(
        [tenure <= 12, tenure <= 36, tenure <= 84],
        ["NEW (<1yr)", "DEVELOPING (1-3yr)", "ESTABLISHED (3-7yr)"],
        default="LOYAL (7yr+)",
    )
    age = df["age"].astype(float)
    df["age_group"] = np.select(
        [age <= 25, age <= 41, age <= 57, age <= 76],
        ["GEN_Z", "MILLENNIAL", "GEN_X", "BOOMER"],
        default="SILENT",
    )
    balance = df["total_balance"].astype(float)
    df["balance_tier"] = np.select(
        [balance < 1000, balance < 10000, balance < 100000],
        ["LOW", "MODERATE", "AFFLUENT"],
        default="HIGH_NET_WORTH",
    )

    # STEP 3/4 — standardise, then k-means on the same six SAS VAR columns.
    features = [
        "log_balance",
        "tenure_months",
        "credit_utilization_pct",
        "product_breadth",
        "acct_ratio",
        "age",
    ]
    scaled = scaler_cls().fit_transform(df[features].astype(float).to_numpy())
    kmeans = kmeans_cls(
        n_clusters=5,
        n_init=10,
        max_iter=50,
        tol=0.001,
        random_state=42,
    ).fit(scaled)
    df["segment_id"] = kmeans.labels_

    # STEP 5 — business labels ordered by descending mean balance, exactly as
    # PROC SQL/`order by AVG_BALANCE desc` + the _N_ ladder in the SAS code.
    # Standardisation is a positive linear transform, so ordering on the raw
    # log balance is identical to ordering on the standardised column.
    ordered_clusters = (
        df.groupby("segment_id")["log_balance"].mean().sort_values(ascending=False).index
    )
    segment_names = [
        "PREMIUM_WEALTH",
        "ENGAGED_MAINSTREAM",
        "GROWING_DIGITAL",
        "CREDIT_DEPENDENT",
        "VALUE_BASIC",
    ]
    label_map = dict(zip(ordered_clusters, segment_names))
    df["segment_name"] = df["segment_id"].map(label_map)

    # STEP 6 — scores, bands and action flags.
    out = pd.DataFrame(
        {
            "CUSTOMER_ID": df["customer_id"].astype("int64"),
            "SEGMENT_NAME": df["segment_name"],
            "SEGMENT_ID": df["segment_id"].astype("int64"),
            "SUBSEGMENT_ID": np.int64(0),
            "LIFETIME_VALUE_SCORE": (
                df["log_balance"] * tenure * df["product_breadth"] * 10
            ).round(2),
            "ENGAGEMENT_SCORE": (df["acct_ratio"] * 100).round(2),
            # Placeholder in the SAS program too (enriched later by txn analytics).
            "DIGITAL_ADOPTION_SCORE": 0.0,
            "PRODUCT_BREADTH_INDEX": (df["product_breadth"] * 100).round(2),
            "TENURE_GROUP": df["tenure_group"],
            "AGE_GROUP": df["age_group"],
            "BALANCE_TIER": df["balance_tier"],
            "CHANNEL_PREFERENCE": None,
            "CROSS_SELL_FLAG": np.where(
                (df["product_breadth"] < 0.50) & (df["acct_ratio"] >= 0.75), "Y", "N"
            ),
            "UPSELL_FLAG": np.where(
                (df["balance_tier"] == "MODERATE")
                & (df["tenure_group"] != "NEW (<1yr)"),
                "Y",
                "N",
            ),
            "RETENTION_RISK_FLAG": np.where(
                (df["acct_ratio"] < 0.50) & (tenure >= 60), "Y", "N"
            ),
            "MODEL_VERSION": "SEG_V3.2",
            "EFFECTIVE_DATE": pd.Timestamp.now().date(),
            "LOAD_TS": pd.Timestamp.now(),
        }
    )
    out["CHANNEL_PREFERENCE"] = out["CHANNEL_PREFERENCE"].astype("object")
    return out.sort_values("CUSTOMER_ID").reset_index(drop=True)

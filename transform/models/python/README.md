# SAS statistical models ported to dbt Python models

| dbt model | Legacy program | SAS procedure | Golden baseline |
|---|---|---|---|
| `sas_customer_segments` | `sas/premium_finance/01_sas_customer_segments.sas` | `PROC STDIZE` + `PROC FASTCLUS` (k=5) | `golden_customer_segments` |
| `sas_customer_risk_scores` | `sas/premium_finance/03_sas_risk_scoring.sas` | `PROC LOGISTIC` (stepwise) | `golden_customer_risk_scores` |

Both are dbt Python models and run on **both** engines:

| target | runtime | libraries |
|---|---|---|
| `duckdb` (default) | local Python process, pandas DataFrames | `pandas`, `numpy`, `scikit-learn` from `requirements.txt` |
| `snowflake` | Snowpark stored procedure | same packages resolved from the Snowpark Anaconda channel via `dbt.config(packages=[...])` (`pandas`, `pyarrow`, `numpy`, `scikit-learn`; `pyarrow` is required for `Snowpark.to_pandas()` inside the stored procedure) |

```bash
cd transform
pip install -r requirements.txt          # includes scikit-learn for the local engine
dbt build --select models/python models/marts tests/sas --profiles-dir .
dbt build --select models/python models/marts tests/sas -t snowflake --profiles-dir .
```

`dbt.ref()` returns a `DuckDBPyRelation` on dbt-duckdb and a Snowpark DataFrame
on dbt-snowflake; both models normalise via `.df()` / `.to_pandas()` and lower-cased
column names, and return UPPER-CASE output columns so the same unquoted
identifiers resolve on Snowflake (which case-folds) and DuckDB
(case-insensitive).

Inputs are the immutable `GOLDEN.BASELINE` staging seeds
(`golden_stg_customer_360`, `golden_stg_risk_factors`) — the exact tables the
SAS programs read from `ETL_STAGING_DB`. Once session A's rebuilt BTEQ staging
models land, the `dbt.ref()` calls can be repointed at them without touching
the statistical logic.

## Procedure mapping

| SAS | dbt Python | Notes |
|---|---|---|
| `PROC STDIZE method=std` | `sklearn.preprocessing.StandardScaler` | SAS divides by the sample SD (n−1), scikit-learn by the population SD (n). A constant positive scale factor per column; it does not change the k-means partition on this data. |
| `PROC FASTCLUS maxclusters=5 maxiter=50 converge=0.001 replace=full least=2` | `KMeans(n_clusters=5, max_iter=50, tol=0.001, n_init=10, random_state=42)` | `least=2` is Euclidean/least-squares, i.e. standard k-means. FASTCLUS seeds by scanning observations (`replace=full`); scikit-learn uses k-means++ with 10 restarts. Initialisation therefore differs by construction. |
| `PROC LOGISTIC descending selection=stepwise slentry=0.10 slstay=0.05` | `LogisticRegression(C=1e6, max_iter=1000)` | Unpenalised MLE (large `C`) via lbfgs vs SAS Fisher scoring. Stepwise selection is **not** reproduced — see below. |

## Parity tolerance and rationale

Statistical parity is asserted with an explicit tolerance rather than
bit-exact equality, in two layers:

1. `golden_parity` with `round_columns` (see `_sas_python_models.yml`) — full
   row/column diff against the golden seed with scores rounded to the
   precision the SAS `round(x, 0.01)` calls already imply.
2. Dedicated tolerance tests, `tests/sas/assert_segments_tolerance.sql` and
   `tests/sas/assert_risk_scores_tolerance.sql`, which state the tolerance
   independently of the rounding so numbers cannot silently drift.

| Quantity | Tolerance | Why |
|---|---|---|
| `segment_name` (cluster membership) | exact | Cluster *membership* is the business output. With standardised features and 10 k-means++ restarts the partition on this data is stable and reproduces the baseline exactly. |
| `segment_id` (raw cluster number) | exact today, informational | k-means cluster numbering is arbitrary and library/version dependent. It matches the baseline on both engines today; if a future scikit-learn build renumbers clusters this is a *labelling* diff only and belongs in `seeds/parity_allowlist.csv`, not a code change. `segment_name` is the stable identifier. |
| `lifetime_value_score`, `engagement_score`, `product_breadth_index` | ±0.01 | Deterministic arithmetic on the staging columns; only 2 dp rounding / floating-point noise is admissible. |
| `composite_risk_score` and the five risk components | ±0.01 | Deterministic weighted scorecard; the SAS DATA step itself rounds the composite to 2 dp. |
| `probability_of_default` | ±0.005 | Optimiser differences (SAS Fisher scoring vs scikit-learn lbfgs), no stepwise variable selection, and different convergence criteria make bit-exact equality of a fitted probability meaningless. |
| `risk_tier`, driver labels, action flags | exact | Business rules applied to the rounded/derived values. |
| `effective_date`, `load_ts` | excluded | Run-time stamps (`today()` / `datetime()` in SAS). |

### Degenerate logistic target (documented legacy behaviour)

The SAS target is `DEFAULT_FLAG = (PAYMENT_LATE_CNT > 2)`. In the migrated
data no customer has more than two late payments, so the target has a single
class: SAS produced a constant `PROBABILITY_OF_DEFAULT = 0.05` for all 407
rows in the baseline. The port mirrors this exactly — it fits
`LogisticRegression` only when both classes are present and otherwise falls
back to the same constant (`DEGENERATE_PROB_DEFAULT = 0.05`). The `PROC
LOGISTIC` stepwise selection is consequently unexercised; when a genuine
default target arrives, the stepwise step should be reintroduced explicitly
(e.g. sequential p-value elimination) rather than assumed.

### Banding boundaries

The SAS source bands with strict `<` cutoffs (`if AGE < 25 then 'GEN_Z'`), but
the GOLDEN baseline that the legacy run actually produced is inclusive of the
upper bound (`GEN_Z` covers ages up to and including 25, `MILLENNIAL` up to 41,
`GEN_X` up to 57, `BOOMER` up to 76; `NEW (<1yr)` covers tenure up to and
including 12 months, `DEVELOPING` up to 36, `ESTABLISHED` up to 84). The port
reproduces the **baseline** behaviour, i.e. the data the downstream estate has
consumed for years, and records the one-year discrepancy against the SAS text
here. 28 of 407 customers (23 age bands, 5 tenure bands) would land in a
different band if the literal `<` cutoffs were used; balance tiers are
unaffected (`<` retained, no balance sits exactly on a boundary).

### Ties in the risk-driver scan

The SAS DO-loop that picks the top two risk components uses `>` in the source,
which would keep the earlier array element on a tie. `CREDIT_RISK_COMPONENT`
and `100 - BUREAU_SCORE_COMPONENT` are numerically identical by construction,
so every row is a tie, and the baseline shows the *later* element winning
(`PRIMARY_RISK_DRIVER = 'BUREAU_SCORE'`, `SECONDARY = 'CREDIT_UTILIZATION'`).
The port uses `>=` to reproduce the baseline for all 407 rows.

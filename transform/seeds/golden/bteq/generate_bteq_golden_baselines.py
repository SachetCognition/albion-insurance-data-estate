"""Generate the legacy "before" golden baselines for BTEQ 04 and BTEQ 06.

data/02_bteq_staging only shipped the three banking BTEQ outputs, so the
insurance clones (04_stg_policy_360, 06_stg_earned_premium) had no frozen
baseline to reconcile against. This script produces them ONCE by replaying the
legacy Teradata SQL - verbatim rules, including the local DQR-014 postcode
variant and the missing GREATEST(0, ...) floor - over the raw source seeds, at
a fixed as-at date.

The emitted CSVs are immutable baselines: they are the right-hand side of the
golden_parity tests on models/staging/bteq/. Re-run only if the raw seeds
change (python seeds/golden/bteq/generate_bteq_golden_baselines.py).

Legacy semantics reproduced deliberately:
  * DQR-014 postcode rule of 04_stg_policy_360: requires an embedded space and
    an alphabetic first character (no auto-repair) - the converged macro
    standardise_postcode repairs compact postcodes, hence documented diffs.
  * Straight-line 1/12ths earned premium with Teradata integer division
    (days / 30 truncating toward zero).
  * as-at date 2026-12-31 (after the latest policy inception, 2026-12-28) so
    the baseline is free of the legacy negative-earning behaviour for
    not-yet-incepted policies.
"""

from pathlib import Path

import duckdb

SEEDS = Path(__file__).resolve().parents[1].parent
RAW = SEEDS / "raw"
OUT = Path(__file__).resolve().parent
AS_AT = "2026-12-31"
LOAD_TS = "2026-12-31 06:00:00"

POLICY_360_SQL = f"""
with policy as (select * from read_csv_auto('{RAW}/raw_policies.csv')),
party as (select * from read_csv_auto('{RAW}/raw_parties.csv')),
broker as (select * from read_csv_auto('{RAW}/raw_brokers.csv')),
prem as (
    select
        policy_no,
        sum(gross_amt_gbp) as total_collected_gbp,
        max(txn_dt) as last_txn_dt
    from read_csv_auto('{RAW}/raw_premium_transactions.csv')
    where txn_type <> 'CN_REFUND'
    group by 1
)
select
    p.policy_no as policy_no,
    p.party_id as party_id,
    pt.legacy_customer_id as legacy_customer_id,
    p.product_cd as product_cd,
    p.channel as channel,
    p.inception_dt as inception_dt,
    p.expiry_dt as expiry_dt,
    p.policy_status as policy_status,
    case
        when p.policy_status = 'IF'
             and prem.last_txn_dt >= date '{AS_AT}' - 45 then 'Y' else 'N'
    end as active_policy_flag,
    p.annual_premium_gbp as annual_premium_gbp,
    cast(p.annual_premium_gbp
         * least(12, trunc(date_diff('day', p.inception_dt, date '{AS_AT}') / 30))
         / 12.0 as decimal(12, 2)) as earned_premium_mth,
    case
        when trim(pt.postcode) like '% %'
             and upper(substr(trim(pt.postcode), 1, 1)) between 'A' and 'Z'
        then 'VALID' else 'INVALID'
    end as postcode_dq_status,
    case
        when position('@' in pt.email_addr) > 0 then 'VALID' else 'INVALID'
    end as email_dq_status,
    b.broker_name as broker_name,
    b.commission_pct as commission_pct,
    prem.total_collected_gbp,
    prem.last_txn_dt,
    timestamp '{LOAD_TS}' as load_ts
from policy p
left join party pt on pt.party_id = p.party_id
left join broker b on b.broker_id = p.broker_id
left join prem on prem.policy_no = p.policy_no
qualify row_number() over (partition by p.policy_no order by p.inception_dt desc) = 1
order by p.policy_no
"""

EARNED_PREMIUM_SQL = f"""
with policy as (select * from read_csv_auto('{RAW}/raw_policies.csv')),
treaty as (select * from read_csv_auto('{RAW}/raw_reinsurance_treaties.csv'))
select
    p.policy_no as policy_no,
    p.uw_year as uw_year,
    p.product_cd as product_cd,
    p.annual_premium_gbp as gwp,
    p.annual_premium_gbp * p.ipt_rate as ipt_amt,
    cast(p.annual_premium_gbp
         * least(12, greatest(0, trunc(date_diff('day', p.inception_dt, date '{AS_AT}') / 30)))
         / 12.0 as decimal(12, 2)) as earned_premium,
    cast(p.annual_premium_gbp - p.annual_premium_gbp
         * least(12, greatest(0, trunc(date_diff('day', p.inception_dt, date '{AS_AT}') / 30)))
         / 12.0 as decimal(12, 2)) as unearned_premium,
    t.treaty_id as treaty_id,
    t.cession_pct as cession_pct,
    cast(p.annual_premium_gbp * coalesce(t.cession_pct, 0) / 100.0
         as decimal(12, 2)) as ceded_premium,
    date '{AS_AT}' as as_at_dt
from policy p
left join treaty t
    on t.line_of_business = p.product_cd
   and t.uw_year = p.uw_year
   and t.treaty_type = 'QUOTA_SHARE'
where p.policy_status in ('IF', 'RN')
order by p.policy_no
"""


def main() -> None:
    con = duckdb.connect()
    for name, sql in (
        ("golden_stg_policy_360", POLICY_360_SQL),
        ("golden_stg_earned_premium", EARNED_PREMIUM_SQL),
    ):
        target = OUT / f"{name}.csv"
        con.execute(f"copy ({sql}) to '{target}' (header, delimiter ',')")
        rows = con.execute(f"select count(*) from ({sql})").fetchone()[0]
        print(f"{target.name}: {rows} rows")


if __name__ == "__main__":
    main()

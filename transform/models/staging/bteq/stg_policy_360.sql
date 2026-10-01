{#-
  Port of teradata/bteq/04_stg_policy_360.bteq (insurance clone of BTEQ 01).

  Converged rules (documented intentional diffs vs the legacy baseline):
    * DQR-014 postcode: the legacy local variant required an embedded space and
      an alphabetic first character. This model calls the single canonical
      is_valid_uk_postcode()/standardise_postcode() macros, which auto-repair a
      missing space (Informatica behaviour) before applying the full UK regex,
      so compact postcodes such as 'EC1A1BB' flip INVALID -> VALID. Affected
      rows are listed in seeds/parity_allowlist.csv.
    * DQR-052 julian dates: PLCYMSTR delivers INCEPT_DT as julian YYDDD
      (mainframe/feed_specs/PLCYMSTR_feed_spec.md) and the legacy chain applied
      three different Y2K pivots (49/50/40). inception_dt_dqr052 re-derives the
      inception date from the julian form through the canonical
      julian_to_date() macro (single group pivot 50). No baseline row shifts
      today - every inception year is in 1951..2050 - so this is additive.
    * Earned premium uses the canonical earned_premium() macro (straight-line
      1/12ths, Finance convention) instead of the inline BTEQ arithmetic, which
      also adds the missing GREATEST(0, ...) floor for not-yet-incepted
      policies.

  DQR-007 email validation is left on the legacy '@'-presence rule: no
  canonical macro exists for it yet.

  CURRENT_DATE is replaced by the `bteq_policy_as_at_dt` var so the derived
  as-at columns are reproducible against the frozen golden baseline.
-#}

{%- set as_at = "cast('" ~ var('bteq_policy_as_at_dt', '2026-12-31') ~ "' as date)" -%}

with premium_agg as (
    select
        policy_no,
        sum(gross_amt_gbp) as total_collected_gbp,
        max(txn_dt) as last_txn_dt
    from {{ ref('raw_premium_transactions') }}
    where txn_type <> 'CN_REFUND'
    group by policy_no
),

policy_ranked as (
    select
        policy_no,
        party_id,
        broker_id,
        product_cd,
        channel,
        inception_dt,
        expiry_dt,
        policy_status,
        annual_premium_gbp,
        row_number() over (
            partition by policy_no
            order by inception_dt desc
        ) as policy_rn
    from {{ ref('raw_policies') }}
)

select
    p.policy_no,
    p.party_id,
    pt.legacy_customer_id,
    p.product_cd,
    p.channel,
    p.inception_dt,
    p.expiry_dt,
    p.policy_status,
    -- FINANCE definition: in force AND premium collected in the last 45 days
    case
        when
            p.policy_status = 'IF'
            and {{ days_between('prem.last_txn_dt', as_at) }} <= 45
            then 'Y'
        else 'N'
    end as active_policy_flag,
    p.annual_premium_gbp,
    {{ earned_premium(
        'cast(p.annual_premium_gbp as decimal(12, 2))', 'p.inception_dt', as_at
    ) }}
        as earned_premium_mth,
    case
        when {{ is_valid_uk_postcode('pt.postcode') }} then 'VALID' else 'INVALID'
    end as postcode_dq_status,
    case
        when position('@' in pt.email_addr) > 0 then 'VALID' else 'INVALID'
    end as email_dq_status,
    b.broker_name,
    b.commission_pct,
    prem.total_collected_gbp,
    prem.last_txn_dt,
    current_timestamp as load_ts,
    -- additive canonical columns (not present in the legacy target table)
    {{ standardise_postcode('pt.postcode') }} as postcode_standardised,
    {{ julian_to_date(
        "lpad(cast(mod(extract(year from p.inception_dt), 100) as varchar), 2, '0')"
        ~ " || lpad(cast(dayofyear(p.inception_dt) as varchar), 3, '0')"
    ) }}
        as inception_dt_dqr052,
    {{ party_canonical_key(party_id='p.party_id', legacy_customer_id='pt.legacy_customer_id', nino='pt.nino') }}
        as party_canonical_key
from policy_ranked as p
left join {{ ref('raw_parties') }} as pt
    on p.party_id = pt.party_id
left join {{ ref('raw_brokers') }} as b
    on p.broker_id = b.broker_id
left join premium_agg as prem
    on p.policy_no = prem.policy_no
where p.policy_rn = 1

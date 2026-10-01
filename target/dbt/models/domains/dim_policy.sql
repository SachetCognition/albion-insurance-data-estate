-- Domain: canonical POLICY dimension (P&C + Life).
-- Carries a SINGLE canonical ACTIVE_POLICY_FLAG plus four clearly-named variant
-- flags, so the four conflicting "active policy" definitions (README finding #3;
-- glossaries) are EXPLICIT rather than silently diverging:
--   * active_uw      = P&C status in (IF, RN)                       (Underwriting)
--   * active_finance = P&C IF + premium collected within 45 days    (Finance;
--                      replaces BTEQ 04_stg_policy_360 ACTIVE_POLICY_FLAG)
--   * active_claims  = policy has >=1 OPEN/REOPENED claim            (Claims MI)
--   * active_life    = life CNTRSTS in (AC, GR, RS)                  (Life Ops)
-- Canonical ACTIVE_POLICY_FLAG = the in-force/servicing view: active_uw for P&C,
-- active_life for Life. Reconcile variants via the labelled columns, never by
-- guessing which "active" a report meant.
-- POLICY_STATUS domain is enforced to (IF,RN,LP,CN,EX) by test (DQR-030);
-- legacy CAR/HSE/PD codes are surfaced, not silently dropped.

with policy as (
    select * from {{ ref('stg_policy') }}
),

life as (
    select * from {{ ref('stg_life_policy') }}
),

claims as (
    select
        policy_no,
        count_if(claim_status in ('OPEN', 'REOPENED')) as open_claim_cnt
    from {{ ref('stg_claim') }}
    group by policy_no
),

collections as (
    select
        policy_no,
        max(txn_dt) as last_collection_dt
    from {{ ref('stg_premium_transactions') }}
    where txn_type <> 'CN_REFUND'
    group by policy_no
),

pc as (
    select
        p.policy_no                                   as policy_no,
        'PC'                                          as policy_domain,
        p.party_id                                    as polaris_party_id,
        md5(p.party_id)                               as party_key,
        p.product_cd,
        p.product_name,
        p.broker_id,
        p.channel,
        p.inception_dt,
        p.expiry_dt,
        p.policy_status,
        p.annual_premium_gbp,
        p.ipt_rate,
        p.payment_plan,
        p.uw_year,
        p.source_system,
        -- variant flags
        (p.policy_status in ('IF', 'RN'))             as active_uw,
        (p.policy_status = 'IF'
             and col.last_collection_dt >= dateadd('day', -45, current_date())
        )                                             as active_finance,
        (coalesce(cl.open_claim_cnt, 0) > 0)          as active_claims,
        cast(null as boolean)                         as active_life,
        col.last_collection_dt
    from policy p
    left join claims cl on cl.policy_no = p.policy_no
    left join collections col on col.policy_no = p.policy_no
),

lf as (
    select
        l.life_policy_id                              as policy_no,
        'LIFE'                                        as policy_domain,
        cast(null as varchar)                         as polaris_party_id,
        coalesce(md5(l.matched_party_id),
                 md5('LIFE400:' || l.life_policy_id)) as party_key,
        l.plan_cd                                     as product_cd,
        'Term Life (LIFE400)'                         as product_name,
        cast(null as varchar)                         as broker_id,
        'LIFE400'                                     as channel,
        l.process_dt                                  as inception_dt,
        cast(null as date)                            as expiry_dt,
        l.contract_status                             as policy_status,
        l.annualised_premium_in_force                 as annual_premium_gbp,
        cast(null as decimal(5, 4))                   as ipt_rate,
        cast(null as varchar)                         as payment_plan,
        year(l.process_dt)                            as uw_year,
        'LIFE400'                                     as source_system,
        cast(null as boolean)                         as active_uw,
        cast(null as boolean)                         as active_finance,
        cast(null as boolean)                         as active_claims,
        (l.contract_status in ('AC', 'GR', 'RS'))     as active_life,
        cast(null as date)                            as last_collection_dt
    from life l
),

unioned as (
    select * from pc
    union all
    select * from lf
)

select
    *,
    -- SINGLE canonical active flag
    case
        when policy_domain = 'PC' then active_uw
        when policy_domain = 'LIFE' then active_life
        else false
    end                                               as active_policy_flag
from unioned

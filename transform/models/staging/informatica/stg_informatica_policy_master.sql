-- Port of informatica/XML/wf_POLICY_MASTER_DAILY.xml (mapping m_POLICY_MASTER_DAILY,
-- target STG_POLICY_MASTER). One CTE per PowerCenter transformation instance:
--   SQ_PLCYMSTR_DAILY      source qualifier over the LEGACY_PAS nightly extract
--   EXP_POLICY_DATES       YYDDD julian -> DATE (DQR-052, converged pivot 50)
--   EXP_POSTCODE_DQ        postcode repair + validate (DQR-014, converged rule)
--   EXP_POLICY_FLAGS       underwriting active-policy flag (status IF / RN)
--   LKP_XREF_CLIENT_PARTY  CLIENT_NO -> PARTY_ID, "Use First Value" on multi-match
with sq_plcymstr_daily as (
    select
        p.policy_no,
        p.product_cd,
        p.policy_status,
        p.annual_premium_gbp,
        pty.legacy_customer_id as plcy_client_no,
        pty.postcode as plcy_postcode,
        pty.last_name as plcy_surname,
        -- the flat file carried the inception date as a YYDDD julian string;
        -- it is reconstructed here so the julian conversion below is exercised
        lpad(cast(mod(year(p.inception_dt), 100) as varchar), 2, '0')
        || lpad(cast(dayofyear(p.inception_dt) as varchar), 3, '0') as plcy_incept_dt_jul
    from {{ ref('raw_policies') }} as p
    left join {{ ref('raw_parties') }} as pty
        on p.party_id = pty.party_id
    where p.source_system = 'LEGACY_PAS'
),

lkp_xref_client_party as (
    -- "Lookup policy on multiple match = Use First Value": one PARTY_ID per
    -- CLIENT_NO. Unmatched client numbers fall through with a null PARTY_ID,
    -- exactly as the legacy lookup did (~12% of rows daily).
    select
        legacy_customer_id as client_no,
        min(party_id) as party_id
    from {{ ref('raw_parties') }}
    where legacy_customer_id is not null
    group by legacy_customer_id
),

exp_policy_dates as (
    select
        sq.*,
        {{ julian_to_date('sq.plcy_incept_dt_jul') }} as inception_dt
    from sq_plcymstr_daily as sq
),

exp_postcode_dq as (
    select
        d.*,
        {{ standardise_postcode('d.plcy_postcode') }} as postcode_std,
        case
            when {{ is_valid_uk_postcode('d.plcy_postcode') }} then 'VALID' else 'INVALID'
        end as postcode_dq_status
    from exp_policy_dates as d
),

exp_policy_flags as (
    select
        pc.*,
        case when pc.policy_status in ('IF', 'RN') then 'Y' else 'N' end as active_policy_flag
    from exp_postcode_dq as pc
)

select
    f.policy_no,
    lkp.party_id,
    {{ party_canonical_key(
        party_id='lkp.party_id',
        legacy_customer_id='f.plcy_client_no'
    ) }} as party_canonical_key,
    cast(f.plcy_client_no as varchar) as client_no,
    f.product_cd,
    f.plcy_incept_dt_jul as inception_dt_julian,
    f.inception_dt,
    cast(f.annual_premium_gbp as decimal(12, 2)) as annual_premium_gbp,
    f.policy_status,
    f.postcode_std,
    f.postcode_dq_status,
    f.plcy_surname as surname,
    f.active_policy_flag,
    case when lkp.party_id is null then 'Y' else 'N' end as xref_unmatched_flag,
    current_timestamp as load_ts
from exp_policy_flags as f
left join lkp_xref_client_party as lkp
    on f.plcy_client_no = lkp.client_no

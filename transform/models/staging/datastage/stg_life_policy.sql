/*
    RECONSTRUCTED business layer of the LOST DataStage job LIFE_POLICY_LOAD,
    i.e. LIFE_DB.LIFE_POLICY plus the derivations of the "century fix" view
    LIFE_DB.V_LIFE_POLICY (teradata/ddl/04_life_db.sql).

    Legacy vs canonical:
      - the legacy view pivoted two-digit DOB years at 40
        (`INSURED_DOB_YYMMDD / 10000 >= 40 -> 1900 + ...`);
      - the group canonical rule is DQR-052 pivot 50, taken here from the
        shared julian_to_date macro so that this model cannot drift from the
        other engines' pivot.
      Two-digit years 40-50 therefore move from 19xx to 20xx. Both the legacy
      and canonical century are exposed side by side with a diff flag, and the
      affected policies are documented intentional parity diffs (DQR-052).

    MATCHED_PARTY_ID came from an in-job name+DOB fuzzy match with no
    surviving crosswalk, threshold or suspect queue, so it is not
    reproducible. It is repopulated here only from deterministic,
    auto-acceptable matches in stg_life_party_resolution (currently none on
    the available feeds) rather than guessed.
*/

with landing as (

    select
        record_seq,
        life_policy_id,
        application_id,
        process_dt_yymmdd,
        plan_cd,
        contract_status,
        insured_name,
        insured_dob_yymmdd,
        insured_dob_str,
        gender,
        sum_assured,
        modal_premium,
        pay_freq
    from {{ ref('stg_life_policy_landing') }}

),

resolution as (

    select
        life_policy_id,
        matched_party_id
    from {{ ref('stg_life_party_resolution') }}
    where is_auto_accepted

),

centuries as (

    select
        landing.*,
        cast(substr(landing.insured_dob_str, 3, 4) as integer) as insured_dob_mmdd,
        extract(
            year from {{ julian_to_date("substr(landing.insured_dob_str, 1, 2) || '001'") }}
        ) as insured_dob_canonical_ccyy,
        case
            when cast(substr(landing.insured_dob_str, 1, 2) as integer) >= 40 then 1900
            else 2000
        end + cast(substr(landing.insured_dob_str, 1, 2) as integer) as insured_dob_legacy_ccyy
    from landing

)

select
    c.life_policy_id,
    c.application_id,
    c.process_dt_yymmdd,
    c.plan_cd,
    c.contract_status,
    c.insured_name,
    c.insured_dob_yymmdd,
    c.gender,
    c.sum_assured,
    c.modal_premium,
    c.pay_freq,
    r.matched_party_id,
    cast(c.insured_dob_canonical_ccyy * 10000 + c.insured_dob_mmdd as bigint) as insured_dob_ccyymmdd,
    cast(c.modal_premium * c.pay_freq as numeric(18, 2)) as annualised_premium_in_force,
    cast(c.insured_dob_legacy_ccyy * 10000 + c.insured_dob_mmdd as bigint) as insured_dob_ccyymmdd_legacy_pivot40,
    c.insured_dob_canonical_ccyy <> c.insured_dob_legacy_ccyy as dob_pivot_diff_flag,
    r.matched_party_id is not null as is_party_resolved
from centuries as c
left join resolution as r
    on c.life_policy_id = r.life_policy_id

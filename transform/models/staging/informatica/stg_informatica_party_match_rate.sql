-- MDM match-rate measurement for the converged wf_PARTY_MDM_SYNC port.
-- The legacy Informatica mapping reported a match rate "stuck at ~55% since the
-- 2024 audit" (see the m_PARTY_MDM_SYNC description). This model recomputes the
-- rate from the converged rules so the delta is auditable, one row per run.
{% set legacy_baseline_pct = 55.0 %}

with base as (
    select
        count(*) as party_cnt,
        sum(case when legacy_customer_id is not null then 1 else 0 end) as legacy_xref_cnt,
        sum(case when match_method = 'LEGACY_XREF' then 1 else 0 end) as converged_legacy_cnt,
        sum(case when match_method = 'APF_EMAIL' then 1 else 0 end) as converged_email_cnt,
        sum(case when match_method = 'APF_NAME_DOB' then 1 else 0 end) as converged_name_dob_cnt,
        sum(case when match_method <> 'UNMATCHED' then 1 else 0 end) as converged_matched_cnt,
        sum(case when match_corroborated_flag = 'Y' then 1 else 0 end) as corroborated_cnt,
        sum(case when mdm_suspect_queue_flag = 'Y' then 1 else 0 end) as suspect_queue_cnt
    from {{ ref('stg_informatica_party_mdm') }}
)

select
    party_cnt,
    legacy_xref_cnt,
    converged_legacy_cnt,
    converged_email_cnt,
    converged_name_dob_cnt,
    converged_matched_cnt,
    corroborated_cnt,
    suspect_queue_cnt,
    cast({{ legacy_baseline_pct }} as decimal(5, 2)) as legacy_reported_match_rate_pct,
    cast(round(100.0 * legacy_xref_cnt / party_cnt, 2) as decimal(5, 2)) as legacy_measured_match_rate_pct,
    cast(round(100.0 * converged_matched_cnt / party_cnt, 2) as decimal(5, 2)) as converged_match_rate_pct,
    cast(
        round(100.0 * converged_matched_cnt / party_cnt - 100.0 * legacy_xref_cnt / party_cnt, 2)
        as decimal(5, 2)
    ) as match_rate_delta_pct
from base

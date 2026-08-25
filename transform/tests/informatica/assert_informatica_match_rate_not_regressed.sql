-- The converged MDM crosswalk must never match fewer parties than the legacy
-- LEGACY_CUSTOMER_ID xref did (legacy reported baseline: 55%).
select
    legacy_measured_match_rate_pct,
    converged_match_rate_pct,
    match_rate_delta_pct
from {{ ref('stg_informatica_party_match_rate') }}
where
    converged_match_rate_pct < legacy_measured_match_rate_pct
    or converged_match_rate_pct < 55.0

-- Staging: LEGACY_PAS PLCYMSTR fixed-width flat feed (FD-001), parsed to columns.
-- See mainframe/copybooks/PLCYMSTR.cpy and mainframe/feed_specs/PLCYMSTR_feed_spec.md.
-- Canonical normalisations applied ONCE here:
--   * POLICY_NO (hyphens stripped on the feed) -> canonical ALB-XXX-9999999.
--   * INCEPT_DT Julian YYDDD -> DATE using the single agreed pivot (replaces the
--     three re-implementations in Informatica EXP_POLICY_DATES / BTEQ 04 / SAS
--     %julian_to_date with pivots 49/50, = DQR-052).
--   * ANNL_PREM pence implied-2dp -> GBP DECIMAL.
--   * POSTCODE standardised (the COBOL 88-level first-char-alpha check, PR4471,
--     is one of the 4 DQR-014 variants replaced here).
-- CLIENT_NO is NOT a party key; it is crosswalked via XREF_CLIENT_PARTY.
with src as (
    select * from {{ source('raw', 'plcymstr') }}
)
select
    {{ normalise_policy_no('policy_no') }}            as policy_no,
    policy_no                                         as policy_no_source,
    try_to_number(to_varchar(client_no))              as client_no,
    upper(trim(product_cd))                           as product_cd,
    {{ julian_yyddd_to_date('to_varchar(incept_dt_jul)') }} as inception_dt,
    {{ pence_to_gbp('annl_prem_pence') }}             as annual_premium_gbp,
    upper(trim(status))                               as policy_status,
    {{ standardise_postcode('postcode') }}            as postcode,
    initcap(trim(surname))                            as surname
from src

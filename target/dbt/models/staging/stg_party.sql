-- Staging: POLICY_ADMIN_DB.PARTY (POLARIS).
-- Replaces the source-side format chaos in ONE canonical place:
--   * BIRTH_DT DD/MM/YYYY text -> DATE (single pivot, replaces DQR-052 divergence)
--   * EMAIL lowercased/trimmed once (replaces DQR-007 variants)
--   * POSTCODE standardised once (replaces the 4 DQR-014 variants)
-- NINO is carried RAW here; masking is applied in the domain layer so that no
-- unmasked NINO reaches an analytical consumer (DQR-021 / AR-118).
with src as (
    select * from {{ source('raw', 'party') }}
)
select
    party_id,
    party_type,
    initcap(trim(first_name))                        as first_name,
    initcap(trim(last_name))                          as last_name,
    {{ parse_ddmmyyyy_text('birth_dt') }}             as birth_dt,
    nino                                              as nino_raw,
    {{ standardise_email('email_addr') }}             as email,
    phone,
    trim(addr_line1)                                  as addr_line1,
    initcap(trim(city))                               as city,
    {{ standardise_postcode('postcode') }}            as postcode,
    try_to_number(to_varchar(legacy_customer_id))     as legacy_customer_id,
    mdm_golden_flag,
    try_to_date(to_varchar(create_dt))                as create_dt
from src

-- Staging: LIFE_DB.LIFE_POLICY (landed LIFE400 POLMSTEX feed, FD-010).
-- Replaces LIFE_DB.V_LIFE_POLICY (teradata/ddl/04_life_db.sql), which applied
-- the divergent pivot-40 century fix. Dates land as raw YYMMDD and are resolved
-- here with the SINGLE agreed pivot (DQR-052). Implied-2dp money -> DECIMAL.
-- LIFE400 has NO postcode field (5th DQR-014 variant) and NO party key
-- (INSURED_NAME free text) — party resolution happens in the domain layer.
with src as (
    select * from {{ source('raw', 'life_policy') }}
)
select
    life_policy_id,
    application_id,
    {{ yymmdd_to_date('process_dt_yymmdd') }}         as process_dt,
    plan_cd,
    upper(trim(contract_status))                      as contract_status,
    trim(insured_name)                                as insured_name,
    {{ yymmdd_to_date('insured_dob_yymmdd') }}        as insured_dob,
    gender,
    {{ pence_to_gbp('sum_assured') }}                 as sum_assured,
    {{ pence_to_gbp('modal_premium') }}               as modal_premium,
    try_to_number(to_varchar(pay_freq))              as pay_freq,
    -- Life "premium" measure = Annualised Premium In Force (API). NOT earned
    -- premium; kept as a clearly-labelled column (glossary/life_operations_glossary.md).
    {{ pence_to_gbp('modal_premium') }} * try_to_number(to_varchar(pay_freq))
                                                      as annualised_premium_in_force,
    nullif(trim(matched_party_id), '')                as matched_party_id
from src

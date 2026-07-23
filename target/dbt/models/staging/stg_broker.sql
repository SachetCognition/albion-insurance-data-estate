-- Staging: POLICY_ADMIN_DB.BROKER. Postcode standardised once (DQR-014).
with src as (
    select * from {{ source('raw', 'broker') }}
)
select
    broker_id,
    broker_name,
    fca_ref,
    initcap(trim(city))                               as city,
    {{ standardise_postcode('postcode') }}            as postcode,
    try_to_decimal(to_varchar(commission_pct), 5, 2)  as commission_pct,
    upper(trim(status))                               as status
from src

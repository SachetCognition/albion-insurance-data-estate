-- Translated from teradata/bteq/04_stg_policy_360.bteq (POLICY_ADMIN_DB.PARTY)
-- BIRTH_DT arrives as DD/MM/YYYY text; converted to a proper DATE here.
with source as (
    select * from {{ ref('parties') }}
)

select
    party_id,
    party_type,
    first_name,
    last_name,
    strptime(birth_dt, '%d/%m/%Y')::date as birth_dt,
    email_addr,
    phone,
    addr_line1,
    city,
    upper(trim(postcode)) as postcode,
    legacy_customer_id,
    mdm_golden_flag,
    create_dt::date as create_dt
from source

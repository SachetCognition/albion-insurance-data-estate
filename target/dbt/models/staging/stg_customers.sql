-- Staging: CORE_BANKING_DB.CUSTOMERS (APF banking, FD-006). This is the source
-- for the CUSTOMER_ID identity scheme; joined into PARTY via
-- PARTY.LEGACY_CUSTOMER_ID. Email normalised once (DQR-007; the APF banking
-- pipeline previously did NO email validation).
with src as (
    select * from {{ source('raw', 'customers') }}
)
select
    try_to_number(to_varchar(customer_id))            as customer_id,
    initcap(trim(first_name))                         as first_name,
    initcap(trim(last_name))                          as last_name,
    try_to_date(to_varchar(date_of_birth))            as date_of_birth,
    ssn_hash,
    {{ standardise_email('email') }}                  as email,
    phone_primary,
    try_to_date(to_varchar(customer_since))           as customer_since,
    upper(trim(customer_status))                      as customer_status,
    upper(trim(segment_code))                         as segment_code,
    try_to_number(to_varchar(branch_id))             as branch_id
from src

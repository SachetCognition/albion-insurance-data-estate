-- Translated from teradata/bteq/04_stg_policy_360.bteq (POLICY_ADMIN_DB.BROKER)
with source as (
    select * from {{ ref('brokers') }}
)

select
    broker_id,
    broker_name,
    fca_ref,
    city,
    postcode,
    commission_pct,
    status
from source

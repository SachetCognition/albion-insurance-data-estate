-- Translated from teradata/bteq/04_stg_policy_360.bteq
-- (BILLING_DB.PREMIUM_TRANSACTIONS). Refunds excluded as in the legacy script.
with source as (
    select * from {{ ref('premium_transactions') }}
)

select
    premium_txn_id,
    policy_no,
    txn_type,
    txn_dt,
    gross_amt_gbp,
    ipt_amt_gbp,
    commission_amt_gbp,
    collection_method,
    apf_account_id
from source
where txn_type <> 'CN_REFUND'

-- Staging: BILLING_DB.PREMIUM_TRANSACTIONS (FD-007). POLICY_NO normalised once.
with src as (
    select * from {{ source('raw', 'premium_transactions') }}
)
select
    try_to_number(to_varchar(premium_txn_id))         as premium_txn_id,
    {{ normalise_policy_no('policy_no') }}            as policy_no,
    upper(trim(txn_type))                             as txn_type,
    try_to_date(to_varchar(txn_dt))                   as txn_dt,
    try_to_decimal(to_varchar(gross_amt_gbp), 12, 2)  as gross_amt_gbp,
    try_to_decimal(to_varchar(ipt_amt_gbp), 12, 2)    as ipt_amt_gbp,
    try_to_decimal(to_varchar(commission_amt_gbp), 12, 2) as commission_amt_gbp,
    upper(trim(collection_method))                    as collection_method,
    try_to_number(to_varchar(apf_account_id))         as apf_account_id
from src

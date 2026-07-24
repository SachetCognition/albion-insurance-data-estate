-- Claims staging for the Policy Inquiry API (replaces ods_claims read by
-- api_legacy/plsql/pkg_policy_inquiry.sql). LOSS_DT arrives as DD/MM/YYYY
-- text (INC0067812); converted to a proper ISO DATE here.
with source as (
    select * from {{ ref('claims') }}
)

select
    claim_no,
    policy_no,
    claimant_party_id,
    strptime(loss_dt, '%d/%m/%Y')::date as loss_dt,
    notification_dt::date as notification_dt,
    cause_cd,
    claim_status,
    incurred_amt,
    paid_amt,
    outstanding_reserve,
    fraud_flag,
    handler_id,
    source_system
from source

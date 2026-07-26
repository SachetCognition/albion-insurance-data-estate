select
    claim_id,
    policy_id,
    loss_date,
    notified_date,
    status,
    cast(incurred_gbp as decimal(15,2)) as incurred_gbp,
    cast(paid_gbp as decimal(15,2)) as paid_gbp,
    fraud_flag
from {{ ref('stg_claims') }}

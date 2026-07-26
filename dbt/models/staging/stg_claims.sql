select
    claim_id,
    policy_id,
    cast(loss_date as date) as loss_date,
    try_cast(nullif(notified_date, '') as date) as notified_date,
    status,
    cast(incurred_gbp as decimal(15,2)) as incurred_gbp,
    cast(paid_gbp as decimal(15,2)) as paid_gbp,
    fraud_flag,
    source_system
from read_csv_auto('../migration/output/claims.csv', header = true, all_varchar = true)

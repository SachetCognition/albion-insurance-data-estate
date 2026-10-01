select
    policy_id,
    legacy_policy_no,
    nullif(party_id, '') as party_id,
    product_code,
    cast(inception_date as date) as inception_date,
    try_cast(nullif(expiry_date, '') as date) as expiry_date,
    status,
    cast(annual_premium_gbp as decimal(15,2)) as annual_premium_gbp,
    cast(nullif(earned_premium_gbp, '') as decimal(15,2)) as earned_premium_gbp,
    nullif(postcode, '') as postcode,
    postcode_dq_status,
    nullif(broker_id, '') as broker_id,
    source_system,
    cast(nullif(modal_premium, '') as decimal(15,2)) as modal_premium,
    nullif(pay_frequency, '') as pay_frequency,
    date_derivation
from read_csv_auto('../migration/output/policies.csv', header = true, all_varchar = true)

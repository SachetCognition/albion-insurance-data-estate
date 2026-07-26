select
    party_id,
    party_type,
    first_name,
    last_name,
    try_strptime(birth_dt, ['%d/%m/%Y', '%Y-%m-%d'])::date as birth_dt,
    nino_hash,
    email_addr,
    phone,
    addr_line1,
    city,
    postcode,
    legacy_customer_id,
    mdm_golden_flag,
    cast(create_dt as date) as create_dt
from read_csv_auto('../migration/output/parties.csv', header = true, all_varchar = true)

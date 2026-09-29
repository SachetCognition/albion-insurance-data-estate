/*
    Client / address attributes carried on feed FD-001 (LEGACY_PAS PLCYMSTR,
    mainframe/feed_specs/PLCYMSTR_feed_spec.md), parsed here only as the
    best available substitute for the never-migrated AS/400 ADDRMST
    correspondence addresses (see the README in this folder).

    Two shared canonical rules are applied here rather than re-implemented:
      - standardise_postcode / is_valid_uk_postcode (DQR-014). The feed
        carries postcodes with no embedded space and only a first-char-alpha
        COBOL 88-level check (PR4471), so the auto-repair is material.
      - julian_to_date (DQR-052 pivot 50) for INCEPT_DT, which really is a
        Julian YYDDD field.
*/

with landing as (

    select
        record_seq,
        raw_record
    from {{ ref('raw_ds_plcymstr_landing') }}

),

column_import as (

    select
        record_seq,
        trim(substr(raw_record, 1, 18)) as policy_no,
        trim(substr(raw_record, 19, 10)) as client_no,
        trim(substr(raw_record, 29, 4)) as product_cd,
        trim(substr(raw_record, 33, 5)) as incept_dt_julian,
        trim(substr(raw_record, 38, 11)) as annl_prem_str,
        trim(substr(raw_record, 49, 2)) as status,
        trim(substr(raw_record, 51, 8)) as postcode_raw,
        trim(substr(raw_record, 59, 20)) as surname
    from landing

)

select
    record_seq,
    policy_no,
    client_no,
    product_cd,
    status,
    surname,
    postcode_raw,
    incept_dt_julian,
    {{ standardise_postcode('postcode_raw') }} as postcode,
    {{ is_valid_uk_postcode('postcode_raw') }} as is_valid_postcode,
    {{ julian_to_date('incept_dt_julian') }} as inception_dt,
    cast(try_cast(annl_prem_str as numeric(15, 2)) / 100 as numeric(13, 2)) as annual_premium
from column_import

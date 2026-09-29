/*
    RECONSTRUCTED column-import stage of the LOST DataStage job
    LIFE_POLICY_LOAD (source gone since the 2018 out-of-support decision).

    Rebuilt from three surviving artefacts, not from the job export:
      - as400_life/feed_specs/POLMSTEX_feed_spec.md  (FD-010 fixed-width map)
      - teradata/ddl/04_life_db.sql                 (LIFE_DB.LIFE_POLICY DDL)
      - as400_life/LIFE400/QCPYSRC/POLDATA.cpy +
        as400_life/LIFE400/QDDSSRC/POLMST.pf        (COBOL/DDS field types)

    Recovery assumptions (see README.md in this folder):
      1. Records are 116 bytes, no delimiter, positions exactly per FD-010.
      2. SUMASSURED / MODALPREM are 13.2 with implied decimals -> /100.
      3. Dates land as INTEGER YYMMDD exactly as received, per the DDL note;
         no century logic happens in the load itself.
      4. PAYFREQ is payments per annum (01/04/12).
*/

with landing as (

    select
        record_seq,
        raw_record
    from {{ ref('raw_ds_polmstex_landing') }}

),

column_import as (

    select
        record_seq,
        length(raw_record) as record_length,
        trim(substr(raw_record, 1, 12)) as life_policy_id,
        trim(substr(raw_record, 13, 12)) as application_id,
        trim(substr(raw_record, 25, 6)) as process_dt_str,
        trim(substr(raw_record, 31, 5)) as plan_cd,
        trim(substr(raw_record, 36, 2)) as contract_status,
        trim(substr(raw_record, 38, 40)) as insured_name,
        trim(substr(raw_record, 78, 6)) as insured_dob_str,
        trim(substr(raw_record, 84, 1)) as gender,
        trim(substr(raw_record, 85, 15)) as sum_assured_str,
        trim(substr(raw_record, 100, 15)) as modal_premium_str,
        trim(substr(raw_record, 115, 2)) as pay_freq_str
    from landing

)

select
    record_seq,
    record_length,
    life_policy_id,
    application_id,
    plan_cd,
    contract_status,
    insured_name,
    gender,
    insured_dob_str,
    try_cast(process_dt_str as bigint) as process_dt_yymmdd,
    try_cast(insured_dob_str as bigint) as insured_dob_yymmdd,
    cast(try_cast(sum_assured_str as numeric(17, 2)) / 100 as numeric(15, 2)) as sum_assured,
    cast(try_cast(modal_premium_str as numeric(17, 2)) / 100 as numeric(15, 2)) as modal_premium,
    try_cast(pay_freq_str as bigint) as pay_freq
from column_import

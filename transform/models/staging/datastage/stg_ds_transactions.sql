/*
    Port of the Transactions_Fact sequential-file stage of the DataStage job
    RETAIL_DATA_MART_Job (datastage/jobs/RETAIL_DATA_MART_Job.dsx).

    The legacy stage read datastage/source_data/transactiondata.txt with
    delimiter ',', firstLineColumnNames=1 and int32 numeric columns. One
    production record carries an unescaped comma inside Description, which the
    legacy stage rejected silently (it never reached RETAIL_DATA_MART.txt).
    The reject is made explicit here instead of being dropped invisibly.
*/

with landing as (

    select
        record_seq,
        raw_record
    from {{ ref('raw_ds_transaction_landing') }}
    where record_seq > 1  -- record_seq = 1 is the column-name header line

),

split_fields as (

    select
        record_seq,
        raw_record,
        length(raw_record) - length(replace(raw_record, ',', '')) + 1 as field_count,
        trim(split_part(raw_record, ',', 1)) as stockid_str,
        trim(split_part(raw_record, ',', 2)) as invoiceid,
        trim(split_part(raw_record, ',', 3)) as description,
        trim(split_part(raw_record, ',', 4)) as quantity_str,
        trim(split_part(raw_record, ',', 5)) as invoicedate_str,
        trim(split_part(raw_record, ',', 6)) as price_str,
        trim(split_part(raw_record, ',', 7)) as customerid_str,
        trim(split_part(raw_record, ',', 8)) as country,
        trim(split_part(raw_record, ',', 9)) as productid_str
    from landing

),

typed as (

    select
        record_seq,
        raw_record,
        field_count,
        invoiceid,
        description,
        country,
        try_cast(stockid_str as bigint) as stockid,
        try_cast(quantity_str as bigint) as quantity,
        try_cast(invoicedate_str as bigint) as invoicedate,
        try_cast(price_str as bigint) as price,
        try_cast(customerid_str as bigint) as customerid,
        try_cast(productid_str as bigint) as productid
    from split_fields

)

select
    record_seq,
    stockid,
    invoiceid,
    description,
    quantity,
    invoicedate,
    price,
    customerid,
    country,
    productid,
    field_count,
    raw_record,
    case
        when field_count <> 9 then 'FIELD_COUNT_' || cast(field_count as varchar)
        when stockid is null then 'STOCKID_NOT_NUMERIC'
        when quantity is null then 'QUANTITY_NOT_NUMERIC'
        when invoicedate is null then 'INVOICEDATE_NOT_NUMERIC'
        when price is null then 'PRICE_NOT_NUMERIC'
        when customerid is null then 'CUSTOMERID_NOT_NUMERIC'
        when productid is null then 'PRODUCTID_NOT_NUMERIC'
    end as reject_reason,
    field_count <> 9 as is_rejected
from typed

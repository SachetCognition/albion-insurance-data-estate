/*
    Port of DataStage job RETAIL_DATA_MART_Job
    (datastage/jobs/RETAIL_DATA_MART_Job.dsx).

    Stage flow in the .dsx:
      Customer_File ---\
      Transaction_File--> Join_1 (key CustomerID, inner)
                            -> Join_2 (key Stockid, inner, Retail_File)
                            -> Join_3 (key productid, inner, Product_File)
                            -> Filter  -where 'customertype like "citizen"
                                        or customertype like "foriegn"'
                            -> Transformer (pass-through, column re-order)
                            -> RETAIL_DATA_MART.txt

    Two documented departures from the legacy job:
      1. int32 saturation. The legacy links typed InvoiceDate as int32, so 14
         records land as 2147483647 in the baseline output. Here InvoiceDate
         is bigint and keeps its source value; those 14 records are
         allow-listed intentional diffs (DQR ref: DS-OVERFLOW-01).
      2. Rejected input records never enter the join, matching the legacy
         behaviour, but the reject is explicit in stg_ds_transactions.
*/

with transactions as (

    select
        stockid,
        invoiceid,
        description,
        quantity,
        invoicedate,
        price,
        customerid,
        country,
        productid
    from {{ ref('stg_ds_transactions') }}
    where not is_rejected

),

customer_dim as (

    select
        customerid,
        customername,
        spendingscore,
        annualincomek,
        gender,
        age,
        customertype
    from {{ ref('raw_ds_customer') }}

),

store_dim as (

    select
        stockid,
        name,
        rating,
        location,
        noofemployees
    from {{ ref('raw_ds_retail_store') }}

),

product_dim as (

    select
        productid,
        productname,
        category,
        subcategory,
        sales,
        quantity as product_quantity
    from {{ ref('raw_ds_product') }}

),

joined as (

    select
        p.productid,
        p.productname,
        p.category,
        p.subcategory,
        p.sales,
        p.product_quantity,
        c.customerid,
        c.customername,
        c.spendingscore,
        c.annualincomek,
        c.gender,
        c.age,
        c.customertype,
        s.stockid,
        s.name,
        s.rating,
        s.location,
        s.noofemployees,
        t.invoiceid,
        t.description,
        t.invoicedate,
        t.price,
        t.country
    from transactions as t
    inner join customer_dim as c
        on t.customerid = c.customerid
    inner join store_dim as s
        on t.stockid = s.stockid
    inner join product_dim as p
        on t.productid = p.productid

)

select
    productid,
    productname,
    category,
    subcategory,
    sales,
    product_quantity as quantity,
    customerid,
    customername,
    spendingscore,
    annualincomek,
    gender,
    age,
    customertype,
    stockid,
    name,
    rating,
    location,
    noofemployees,
    invoiceid,
    description,
    invoicedate,
    price,
    country
from joined
where customertype like 'citizen' or customertype like 'foriegn'

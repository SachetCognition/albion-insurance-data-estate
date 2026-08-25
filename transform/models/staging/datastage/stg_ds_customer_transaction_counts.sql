/*
    Port of DataStage job Count_Customer_Transactions_Job
    (datastage/jobs/Count_Customer_Transactions_Job.dsx).

    Stage flow: RETAIL_DATA_MART.txt -> PxAggregator
    (-key 'CustomerID' -key 'Stockid', count output column total_orders_num)
    -> Count_Customers_Transactions.txt. The aggregator reads the output of
    RETAIL_DATA_MART_Job, so this model aggregates that model rather than
    re-reading the sequential file.
*/

select
    customerid,
    stockid,
    count(*) as total_orders_num
from {{ ref('stg_ds_retail_data_mart') }}
group by customerid, stockid

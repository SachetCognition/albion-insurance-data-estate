{#-
  Port of teradata/bteq/01_stg_customer_360.bteq (banking clone).

  Legacy BTEQ built ETL_STAGING_DB.STG_CUSTOMER_360 as a DROP/CREATE MULTISET
  TABLE ... WITH DATA; the dbt equivalent is a table materialisation, so the
  BTEQ scaffolding (.LOGON, DROP TABLE, COLLECT STATISTICS, row-count
  validation, ETL_RUN_LOG insert) is replaced by dbt's own DDL, warehouse
  statistics, and the schema tests in _bteq.yml.

  CURRENT_DATE is replaced by the `bteq_customer_as_at_dt` var so the derived
  AGE / TENURE_MONTHS / address-effectivity columns are reproducible and can
  be compared against the frozen golden baseline (generated 2026-04-10).
-#}

{%- set as_at = "cast('" ~ var('bteq_customer_as_at_dt', '2026-04-10') ~ "' as date)" -%}

with primary_address as (
    -- most recent non-expired HOME address (BTEQ QUALIFY ROW_NUMBER)
    select
        customer_id,
        address_line_1,
        address_line_2,
        city,
        state_code,
        zip_code,
        row_number() over (
            partition by customer_id
            order by effective_date desc
        ) as addr_rn
    from {{ ref('raw_addresses') }}
    where
        address_type = 'HOME'
        and (expiration_date is null or expiration_date > {{ as_at }})
),

account_agg as (
    select
        customer_id,
        count(*) as num_accounts,
        sum(case when account_status = 'O' then 1 else 0 end) as num_active_accounts,
        max(case when account_type = 'CHECKING' then 'Y' else 'N' end) as has_checking,
        max(case when account_type = 'SAVINGS' then 'Y' else 'N' end) as has_savings,
        max(case when account_type = 'CREDIT' then 'Y' else 'N' end) as has_credit,
        max(case when account_type = 'LOAN' then 'Y' else 'N' end) as has_loan,
        sum(coalesce(current_balance, 0)) as total_balance,
        sum(
            case when account_type = 'CREDIT' then coalesce(credit_limit, 0) else 0 end
        ) as total_credit_limit,
        sum(
            case when account_type = 'CREDIT' then coalesce(current_balance, 0) else 0 end
        ) as credit_balance
    from {{ ref('raw_accounts') }}
    group by customer_id
)

select
    c.customer_id,
    c.first_name,
    c.last_name,
    c.date_of_birth,
    -- BTEQ: CAST((CURRENT_DATE - DATE_OF_BIRTH) / 365.25 AS SMALLINT).
    -- The legacy target table holds the calendar-year difference, which the
    -- 365.25 expression only approximates (it disagrees for 128/478 baseline
    -- rows), so the reproducible year difference is used here.
    cast(
        extract(year from {{ as_at }}) - extract(year from c.date_of_birth) as integer
    ) as age,
    c.customer_since,
    -- BTEQ: CAST(MONTHS_BETWEEN(CURRENT_DATE, CUSTOMER_SINCE) AS INTEGER)
    cast(datediff('month', c.customer_since, {{ as_at }}) as integer) as tenure_months,
    c.customer_status,
    c.segment_code,
    c.branch_id,
    trim(a.address_line_1)
    || coalesce(', ' || trim(a.address_line_2), '') as primary_address,
    a.city,
    a.state_code,
    a.zip_code,
    acct.num_accounts,
    acct.num_active_accounts,
    acct.has_checking,
    acct.has_savings,
    acct.has_credit,
    acct.has_loan,
    acct.total_balance,
    acct.total_credit_limit,
    case
        when acct.total_credit_limit > 0
            then cast(acct.credit_balance / acct.total_credit_limit * 100 as decimal(5, 2))
        else 0.00
    end as credit_utilization_pct,
    current_timestamp as load_ts
from {{ ref('raw_customers') }} as c
left join primary_address as a
    on c.customer_id = a.customer_id and a.addr_rn = 1
left join account_agg as acct
    on c.customer_id = acct.customer_id
where c.customer_status in ('A', 'I')   -- exclude closed customers

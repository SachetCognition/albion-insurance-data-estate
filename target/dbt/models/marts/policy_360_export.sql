-- CSV export of the policy_360 mart consumed by the Policy Inquiry API
-- (target/api). DuckDB-profile integration hand-off; on Snowflake this would
-- be an unload/share instead.
{{ config(materialized='external', location='exports/policy_360.csv', format='csv') }}

select * from {{ ref('policy_360') }}

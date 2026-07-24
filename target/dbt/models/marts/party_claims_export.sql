-- CSV export of the party_claims mart consumed by the Policy Inquiry API
-- (target/api).
{{ config(materialized='external', location='exports/party_claims.csv', format='csv') }}

select * from {{ ref('party_claims') }}

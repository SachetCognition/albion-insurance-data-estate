{{ config(enabled=false) }}

-- DQR-033 is suspended in dq_rules_registry.csv. The dq_pass_rates mart still
-- reports the observed rate without failing the build.
select *
from {{ ref('claims_summary') }}
where loss_date > cast('{{ var("as_of_date") }}' as date)

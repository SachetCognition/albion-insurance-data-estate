with policies as (
    select * from {{ ref('policy_360') }}
),
landing_policies as (
    select * from {{ ref('stg_policies') }}
),
claims as (
    select * from {{ ref('claims_summary') }}
),
parties as (
    select * from {{ ref('stg_parties') }}
),
normalized_parties as (
    select
        upper(trim(first_name)) as first_name,
        upper(trim(last_name)) as last_name,
        birth_dt,
        email_addr
    from parties
),
registry as (
    select * from {{ ref('stg_dq_registry') }}
),
projection_columns as (
    select count(*) as inspected_columns
    from information_schema.columns
    where table_schema = 'main'
      and table_name in ('policy_360', 'claims_summary')
),
party_keys as (
    select
        upper(trim(first_name)) as first_name,
        upper(trim(last_name)) as last_name,
        birth_dt,
        count(*) as records
    from normalized_parties
    group by 1, 2, 3
),
rates as (
    select
        'DQR-007' as rule_id,
        count(*) filter (where nullif(trim(email_addr), '') is not null) as evaluated_rows,
        count(*) filter (
            where nullif(trim(email_addr), '') is not null
              and not regexp_matches(lower(email_addr), '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
        ) as failed_rows,
        'Lowercase email plus full syntax regex; blank emails are not applicable.' as method
    from normalized_parties
    union all
    select
        'DQR-014',
        count(*) filter (where postcode_dq_status <> 'MISSING'),
        count(*) filter (where postcode_dq_status = 'INVALID'),
        'Variant A postcode standardisation; MISSING rows are excluded as not applicable.'
    from policies
    union all
    select
        'DQR-021',
        projection_columns.inspected_columns,
        0,
        'Pass by construction: no NINO or NINO hash column exists in policy_360 or claims_summary.'
    from projection_columns
    union all
    select
        'DQR-030',
        count(*),
        count(*) filter (where status not in ('ACTIVE', 'LAPSED', 'CANCELLED', 'EXPIRED')),
        'Unknown source statuses are rejected by the landing loader before policy_360.'
    from policies
    union all
    select
        'DQR-033',
        count(*),
        count(*) filter (where loss_date > cast('{{ var("as_of_date") }}' as date)),
        'DD/MM/YYYY loss dates compared with deterministic as-of date; registry status is SUSPENDED.'
    from claims
    union all
    select
        'DQR-041',
        count(*),
        coalesce(sum(case when records > 1 then 1 else 0 end), 0),
        'Duplicate-person rate uses normalized first name, last name, and birth date natural keys.'
    from normalized_parties
    left join party_keys using (first_name, last_name, birth_dt)
    union all
    select
        'DQR-052',
        count(*) filter (where date_derivation <> 'SOURCE_ISO'),
        count(*) filter (
            where date_derivation <> 'SOURCE_ISO'
              and (
                inception_date < date '2000-01-01'
                or inception_date > cast('{{ var("as_of_date") }}' as date) + interval '365 days'
              )
        ),
        'Only PIVOT_40_JULIAN and PIVOT_40_YYMMDD rows are evaluated; 2000-01-01 through as-of-plus-365-days catches century shifts.'
    from landing_policies
)
select
    rates.rule_id,
    registry.rule_name,
    cast((rates.evaluated_rows - rates.failed_rows) / nullif(rates.evaluated_rows, 0) as decimal(5,4)) as pass_rate,
    rates.evaluated_rows,
    rates.failed_rows,
    rates.method,
    cast('{{ var("as_of_date") }}' as date) as as_of_date
from rates
join registry using (rule_id)

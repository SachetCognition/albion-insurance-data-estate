-- Adversarial sensitivity test for the golden_parity harness.
-- Replays the harness's bidirectional EXCEPT diff against deliberately
-- mutated copies of a golden baseline and fails if the diff logic would
-- MISS the mutation (i.e. proves the parity harness cannot silently pass
-- on a broken model).
with golden as (
    select * from {{ ref('golden_stg_customer_360') }}
),

pivot_key as (
    select min(customer_id) as customer_id from golden
),

-- mutation 1: a row silently dropped from the rebuilt model
dropped_row as (
    select golden.*
    from golden
    cross join pivot_key
    where golden.customer_id <> pivot_key.customer_id
),

-- mutation 2: a single value changed on one row
value_changed as (
    select golden.* replace (golden.tenure_months + 99 as tenure_months)
    from golden
    cross join pivot_key
    where golden.customer_id = pivot_key.customer_id
    union all
    select golden.*
    from golden
    cross join pivot_key
    where golden.customer_id <> pivot_key.customer_id
),

detection as (
    select
        (
            select count(*) from (
                select * from golden
                except
                select * from dropped_row
            ) as d1
        ) as drop_golden_only,
        (
            select count(*) from (
                select * from dropped_row
                except
                select * from golden
            ) as d2
        ) as drop_model_only,
        (
            select count(*) from (
                select * from golden
                except
                select * from value_changed
            ) as d3
        ) as change_golden_only,
        (
            select count(*) from (
                select * from value_changed
                except
                select * from golden
            ) as d4
        ) as change_model_only
)

select *
from detection
where
    drop_golden_only <> 1
    or drop_model_only <> 0
    or change_golden_only <> 1
    or change_model_only <> 1

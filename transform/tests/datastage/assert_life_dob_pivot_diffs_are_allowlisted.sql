-- DQR-052: every life policy whose century changes under the canonical pivot
-- 50 must be a documented intentional diff in seeds/parity_allowlist.csv, and
-- nothing else may be listed there for this baseline. This keeps the
-- allow-list honest in both directions.
with flagged as (

    select life_policy_id
    from {{ ref('stg_life_policy') }}
    where dob_pivot_diff_flag

),

allowlisted as (

    select key_value as life_policy_id
    from {{ ref('parity_allowlist') }}
    where lower(golden_seed) = 'golden_ds_life_policy_recon'

)

select
    'flagged_not_allowlisted' as diff_type,
    f.life_policy_id
from flagged as f
where f.life_policy_id not in (select a.life_policy_id from allowlisted as a)

union all

select
    'allowlisted_not_flagged' as diff_type,
    a.life_policy_id
from allowlisted as a
where a.life_policy_id not in (select f.life_policy_id from flagged as f)

-- The production transaction file contains exactly one malformed record (an
-- unescaped comma inside Description), which the legacy DataStage sequential
-- file stage rejected silently. This test pins that reject count so a future
-- parsing change cannot silently start dropping - or start admitting - rows.
with rejects as (

    select count(*) as reject_count
    from {{ ref('stg_ds_transactions') }}
    where is_rejected

),

field_count_rejects as (

    select count(*) as bad_field_count
    from {{ ref('stg_ds_transactions') }}
    where is_rejected and reject_reason not like 'FIELD_COUNT_%'

)

select
    r.reject_count,
    f.bad_field_count
from rejects as r
cross join field_count_rejects as f
where r.reject_count <> 1 or f.bad_field_count <> 0

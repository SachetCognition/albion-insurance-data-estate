-- The FD-010 implied-decimal amounts must survive the reconstruction exactly:
-- sum_assured and modal_premium are re-derived from the raw 13.2 fields, and
-- the annualised premium must equal modal_premium * pay_freq per
-- LIFE_DB.V_LIFE_POLICY.
with raw_amounts as (

    select
        trim(substr(raw_record, 1, 12)) as life_policy_id,
        cast(cast(trim(substr(raw_record, 85, 15)) as numeric(17, 2)) / 100 as numeric(15, 2)) as sum_assured,
        cast(cast(trim(substr(raw_record, 100, 15)) as numeric(17, 2)) / 100 as numeric(15, 2)) as modal_premium,
        cast(trim(substr(raw_record, 115, 2)) as bigint) as pay_freq
    from {{ ref('raw_ds_polmstex_landing') }}

)

select
    p.life_policy_id,
    p.sum_assured,
    r.sum_assured as raw_sum_assured,
    p.modal_premium,
    r.modal_premium as raw_modal_premium,
    p.annualised_premium_in_force
from {{ ref('stg_life_policy') }} as p
inner join raw_amounts as r
    on p.life_policy_id = r.life_policy_id
where
    p.sum_assured <> r.sum_assured
    or p.modal_premium <> r.modal_premium
    or p.pay_freq <> r.pay_freq
    or p.annualised_premium_in_force <> r.modal_premium * r.pay_freq

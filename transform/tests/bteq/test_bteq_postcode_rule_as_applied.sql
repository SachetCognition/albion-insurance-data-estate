-- Unit test: DQR-014 macros AS APPLIED in stg_policy_360.
-- 1. fixed expectations for the postcode shapes present in raw_parties,
--    including the compact form the legacy BTEQ 04 variant rejected;
-- 2. the model's postcode_dq_status / postcode_standardised really are the
--    canonical macro output for every source row (no local re-implementation).
with cases as (
    select * from (
        values
        ('EC1A1BB', 'EC1A 1BB', true),    -- compact: repaired then valid
        ('M1  1AE', 'M1 1AE', true),      -- double space: normalised
        ('  cf10 1ep ', 'CF10 1EP', true),-- lowercase + padding
        ('ZZ99 9ZZ', 'ZZ99 9ZZ', true),   -- pseudo-postcode, valid shape
        ('N/A', 'N/A', false),            -- not repairable
        ('', '', false)
    ) as t (raw_postcode, expected_standardised, expected_valid)
),

macro_cases as (
    select
        raw_postcode,
        expected_standardised,
        expected_valid,
        {{ standardise_postcode('raw_postcode') }} as actual_standardised,
        {{ is_valid_uk_postcode('raw_postcode') }} as actual_valid
    from cases
),

case_failures as (
    select raw_postcode
    from macro_cases
    where
        actual_standardised <> expected_standardised
        or actual_valid <> expected_valid
),

model_failures as (
    select p.policy_no as raw_postcode
    from {{ ref('stg_policy_360') }} as p
    left join {{ ref('raw_parties') }} as pt
        on p.party_id = pt.party_id
    where
        p.postcode_dq_status <> case
            when {{ is_valid_uk_postcode('pt.postcode') }} then 'VALID' else 'INVALID'
        end
        or coalesce(p.postcode_standardised, '~null~')
        <> coalesce({{ standardise_postcode('pt.postcode') }}, '~null~')
)

select raw_postcode from case_failures
union all
select raw_postcode from model_failures

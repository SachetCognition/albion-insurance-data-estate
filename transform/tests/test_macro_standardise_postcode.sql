-- Unit test: DQR-014 canonical postcode standardisation + validation.
-- Covers the historical disagreement inputs called out in the DQ registry
-- ('ec1a 1bb', 'EC1A1BB') plus plain-valid and invalid values.
with cases as (
    select
        'ec1a 1bb' as raw_pc,
        'EC1A 1BB' as expected_std,
        true as expected_valid
    union all
    select
        'EC1A1BB' as raw_pc,
        'EC1A 1BB' as expected_std,
        true as expected_valid
    union all
    select
        'M1 1AE' as raw_pc,
        'M1 1AE' as expected_std,
        true as expected_valid
    union all
    select
        ' cf10 1ep ' as raw_pc,
        'CF10 1EP' as expected_std,
        true as expected_valid
    union all
    select
        '12345' as raw_pc,
        '12 345' as expected_std,
        false as expected_valid
    union all
    select
        'BANANAS99X' as raw_pc,
        'BANANAS99X' as expected_std,
        false as expected_valid
)

select
    raw_pc,
    expected_std,
    {{ standardise_postcode('raw_pc') }} as actual_std,
    expected_valid,
    {{ is_valid_uk_postcode('raw_pc') }} as actual_valid
from cases
where
    {{ standardise_postcode('raw_pc') }} <> expected_std
    or {{ is_valid_uk_postcode('raw_pc') }} <> expected_valid

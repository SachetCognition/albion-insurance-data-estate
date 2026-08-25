-- Repatriated life addresses must carry DQR-014 standardised postcodes: the
-- single canonical space position, upper case, no double spaces. Records that
-- cannot be repaired are allowed to stay invalid (is_valid_postcode = false)
-- but must never be loadable.
select
    life_policy_id,
    postcode_raw,
    postcode,
    is_valid_postcode,
    is_loadable
from {{ ref('stg_life_address_repatriation') }}
where
    postcode <> upper(trim(postcode))
    or postcode like '%  %'
    or (not is_valid_postcode and is_loadable)

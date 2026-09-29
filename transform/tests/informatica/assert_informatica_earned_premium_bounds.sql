-- Earned premium (either method) must sit between zero and the annual premium,
-- and the 1/24ths legacy figure must never be below the canonical 1/12ths
-- figure (the mid-month assumption always earns at least as much).
select
    policy_no,
    annual_premium_gbp,
    earned_premium_24ths_legacy_gbp,
    earned_premium_canonical_gbp
from {{ ref('stg_informatica_billing_premium_recon') }}
where
    earned_premium_24ths_legacy_gbp < 0
    or earned_premium_canonical_gbp < 0
    or earned_premium_24ths_legacy_gbp > annual_premium_gbp
    or earned_premium_canonical_gbp > annual_premium_gbp
    or earned_premium_24ths_legacy_gbp < earned_premium_canonical_gbp

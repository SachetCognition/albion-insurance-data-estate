-- party_claims — claims per party for the Policy Inquiry API endpoint
-- GET /api/v1/parties/{partyId}/claims. Replaces pkg_policy_inquiry.get_party_claims.
-- Single identifier (party_id) only — the legacy dual-key lookup
-- (claimant_party_id OR legacy_client_no) is intentionally not reproduced.

select
    c.claim_no,
    c.policy_no,
    c.claimant_party_id as party_id,
    c.loss_dt,
    c.notification_dt,
    c.cause_cd,
    c.claim_status,
    c.incurred_amt,
    c.paid_amt,
    c.outstanding_reserve
from {{ ref('stg_claims') }} c

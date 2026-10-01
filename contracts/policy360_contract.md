# Policy 360 / Claims — Frozen Shared Contract (ADEM-2)

Source of truth: Jira [ADEM-2](https://cognition-partner-workshops.atlassian.net/browse/ADEM-2),
section "Shared contract (lock this in before splitting)", reproduced **verbatim** below.

This file is frozen. Any change must be routed through the coordinating (parent) session and
back into the Jira ticket first — child workstreams must not edit or reinterpret it.

---

## Shared contract (lock this in before splitting)

Canonical `POLICY_360` row, exposed as `GET /api/v1/policies/{policyId}` and `GET /api/v1/policies?partyId=&status=&page=&size=`:

```
policyId            string   canonical policy key
legacyPolicyNo      string   as-keyed in PLCYMSTR
partyId             string   canonical party id (resolved from CLIENT_NO via xref)
productCode         string
inceptionDate       date     ISO-8601, converted from Julian
expiryDate          date     ISO-8601, nullable
status              enum     ACTIVE | LAPSED | CANCELLED | EXPIRED
annualPremiumGbp    decimal(15,2)   converted from implied pence
earnedPremiumGbp    decimal(15,2)
postcode            string   nullable, standardised
postcodeDqStatus    enum     VALID | INVALID | MISSING
brokerId            string   nullable
sourceSystem        enum     PLCYMSTR | LIFE400 | GUIDEWIRE
```

Claims: `GET /api/v1/policies/{policyId}/claims` and `GET /api/v1/claims/{claimId}` →

```
claimId             string
policyId            string
lossDate            date     ISO-8601, unambiguous
notifiedDate        date
status              enum     OPEN | CLOSED | REOPENED | DECLINED
incurredGbp         decimal(15,2)
paidGbp             decimal(15,2)
fraudFlag           enum     Y | N | SUSPECTED
```

Aggregate for the dashboard: `GET /api/v1/data-products/summary` → active policy count, total earned premium, open claims count, incurred total, and per-rule DQ pass rates keyed by `DQR-*` id.

Errors: RFC-7807 problem+json; unknown id → 404. Money is always a decimal string in GBP. Dates are ISO-8601 only.

---

## Fixtures

JSON payload fixtures for every endpoint above live in `contracts/fixtures/`. They are
derived from the checked-in sample data (`data/01_source_tables/`) and exist so the consumer
API can be developed and tested before the dbt marts land. They are illustrative payload
shapes, not the canonical figures.

| File | Endpoint |
| --- | --- |
| `policies.json` | backing collection for all policy endpoints |
| `policy_ALB-PET-0000001.json` | `GET /api/v1/policies/{policyId}` |
| `policies_page.json` | `GET /api/v1/policies?partyId=&status=&page=&size=` |
| `policy_ALB-PET-0000001_claims.json` | `GET /api/v1/policies/{policyId}/claims` |
| `claims.json` | backing collection for all claim endpoints |
| `claim_CLM00001187.json` | `GET /api/v1/claims/{claimId}` |
| `data_products_summary.json` | `GET /api/v1/data-products/summary` |
| `problem_policy_not_found.json`, `problem_claim_not_found.json` | RFC-7807 `404` bodies |

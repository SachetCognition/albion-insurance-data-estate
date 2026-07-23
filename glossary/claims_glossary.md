# Claims MI Glossary (S. Whitfield, last touched 2024-03)

- **Active Policy** — any policy with at least one OPEN or REOPENED claim,
  regardless of policy status. (Yes, this includes cancelled policies. Yes,
  Finance disagree. This is the definition the claims dashboards use.)
- **Incurred Date** — Claims MI use **LOSS_DT** (date of loss). Finance
  recognise incurred movements on **NOTIFICATION_DT** (their ledger has no
  loss-date field). Reserving triangles are built on loss date. Any figure
  labelled "incurred in month" means different things in different packs.
- **Claim Frequency** — open+closed claims / earned exposure. Exposure comes
  from the UW spreadsheet (see UW glossary), earned premium from Finance;
  numerator and denominator use different "active" definitions.
- **Fraud Referral** — FRAUD_SCORE >= 650 (SIU 0–1000 scale). Not to be
  confused with the APF banking RISK_SCORE (0–1 probability) shown on the same
  Qlik dashboard for overlapping customers.
- **Claimant** — CLAIMANT_PARTY_ID. For legacy claims this is back-filled from
  the policy's party and may not be the actual claimant (third-party claims).

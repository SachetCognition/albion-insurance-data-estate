# Albion General — Assess Phase Deliverables

Written assessment of the Albion General Insurance Group legacy data estate
(SachetCognition/albion-insurance-data-estate). Analysis/documentation only — no
legacy source files were modified. Every finding cites exact file paths and line
numbers as evidence.

## Deliverables
1. **[Feed / pipeline inventory](01_feed_inventory.md)** — all feeds across Informatica
   (5 insurance + 3 GSS workflows), SAS (banking 01–04 + insurance 05–09), Teradata BTEQ
   (01–06), mainframe (PLCYMSTR/CLMHIST/JCL) and AS/400 life (LIFEXTR/POLMSTEX),
   reconciled with `docs/feed_inventory.md`, plus scheduling chaos and 6 gaps.
2. **[Attribute-overlap matrix](02_attribute_overlap_matrix.md)** — key attributes ×
   system, the six identity schemes, two partial crosswalks, ~55% MDM rate, per‑attribute
   format divergence.
3. **[Glossary reconciliation](03_glossary_reconciliation.md)** — term‑by‑term across the
   4 (+Life) glossaries with conflicts flagged and canonical candidates.
4. **[DQ registry diff](04_dq_registry_diff.md)** — 7 registry rules vs. actual code;
   DQR‑014 (5 postcode variants), DQR‑007 (2+gap), NINO/AR‑118, Julian pivots 49/50/40,
   SII LoB drift.

An HTML rendering of all deliverables is provided at **[`assessment.html`](assessment.html)**.

## Headline findings (with pointers)
- **Identity fragmentation** — 6 schemes, 2 partial crosswalks, 55% match, 41k suspects; keyless life book. (D2)
- **Rule duplication & drift** — postcode in 5 variants, NINO raw‑join bypass, 3 Y2K pivots, SII LoB drift. (D4)
- **Metric divergence** — earned premium 1/12 vs 1/24 vs 365ths (+Life API in a Group KPI); 4 "active policy" definitions; 0–1 vs 0–1000 risk scales; fraud `'S'` mapped both ways. (D3)
- **Format chaos** — ISO / DD‑MM text / Julian / YYMMDD / US‑parse bug; pence implied‑decimal; £‑text; 4 policy‑number formats. (D2)
- **Pipeline clone drift & scheduling chaos** — insurance BTEQ/SAS cloned from banking; quadruple scheduling; LIFE_POLICY_LOAD triple‑scheduled; 75‑min FTP gap; undocumented cross‑pipeline kick; nightly race; DQ‑bypassing actuarial feed. (D1)
- **Legacy consumption debt** — 26h‑stale ODS behind a SOAP contract mixing two id schemes; 4th inline re‑key in PL/SQL. (D1/D2)

## Method / caveats
Evidence collected by reading the repo directly (`README.md`, `docs/`, `glossary/`,
`dq_rules/`, all pipeline code). Line numbers refer to the state of `main` at assessment
time. Six documented gaps (missing POLARIS CDC export, missing CLMEXTR JCL, lost
LIFE_POLICY_LOAD .dsx, missing GSS "Pseudossn" mask job, "nightly"=weekly DLYUPD, and
status‑domain leakage) are listed in Deliverable 1 §1.8.

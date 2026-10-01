# Albion legacy data estate — assessment report (ADEM-1)

**[`albion_data_estate_assessment.html`](albion_data_estate_assessment.html)** —
open it directly in a browser. It is a single self-contained file: all CSS and
JavaScript are inlined and it makes no network requests, so it renders offline
and can be emailed or attached as-is.

## What the report covers

1. Executive summary and severity breakdown
2. Estate overview — every governed feed (FD-001 … FD-011) with source system,
   technology, targets, schedule, consumers and owner, **plus the production
   data movements found in code that the inventory does not list**
3. Lineage map per feed: source → ingest → staging → data product → consumption
4. Identity fragmentation — the six identifier schemes and the two partial
   crosswalks
5. Attribute overlap matrix — the same business attribute produced independently
   by up to six systems
6. Conflicting definitions and metric divergence — earned premium (1/12ths vs
   1/24ths vs 365ths) and active policy (four definitions), with business impact
7. DQ and transformation rule overlap and drift, with file-and-line evidence
8. Pipeline clone drift, four-scheduler chaos, legacy consumption debt and
   platform / key-person risk
9. Recommended unified data model: Party, Policy, Claim, Premium & Billing,
   Reinsurance, Life
10. Recommended data domain services and Snowflake + dbt target architecture,
    with alternatives considered, ownership, contracts, DQ placement, migration
    phases and risks
11. Method, reproducibility and scope

Every finding cites real repository paths and line numbers, resolved against the
working tree at generation time.

## Regenerating

```bash
python3 tools/assessment/run_assessment.py
```

The generator lives in [`tools/assessment/`](../../tools/assessment/) — see its
[README](../../tools/assessment/README.md) for how the evidence probes work.

## Machine-readable outputs

Under [`data/`](data/):

| File | Contents |
|---|---|
| `assessment_findings.json` | Full structured dataset behind the report |
| `findings.csv` | One row per finding: category, severity, evidence refs |
| `feed_inventory.csv` | Governed feeds plus feeds discovered only in code |
| `attribute_overlap_matrix.csv` | One row per attribute × producing system |
| `dq_rule_drift.csv` | Registered vs actual DQ rule implementations |
| `schedule_inventory.csv` | Every job across Control-M, cron, AS/400 and DataStage |

## Scope

ADEM-1 produces analysis artefacts only. No pipeline asset was modified: the
only files added are under `tools/assessment/` and `docs/assessment/`.

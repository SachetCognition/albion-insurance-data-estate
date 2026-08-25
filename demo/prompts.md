# Verbatim prompts — paste exactly as written

Use these prompts word-for-word so every take produces the same flow.
Prompts 1–4 are for **Ask Devin** (Segment 2). Prompt 5 is the Agent-mode
prompt that drove the pre-run session shown in Segment 3 — do NOT re-run it
live during a take; it is included for reference and provenance.

---

## Prompt 1 — the modernisation question (Segment 2, shot 2.1)

```
Our legacy data estate is a Teradata warehouse loaded by BTEQ scripts, with
Informatica PowerCenter and IBM DataStage ETL, SAS analytics jobs, and
mainframe/AS-400 nightly feeds. How would you modernise this estate onto a
cloud data platform? Give me a technology-mapping table (each legacy
technology -> modern equivalent) and a phased migration roadmap.
```

## Prompt 2 — narrowing: no Snowflake yet (Segment 2, shot 2.4)

```
We don't have a Snowflake account provisioned yet. How can we start the
migration and prove out the approach locally with zero cloud credentials —
for example on DuckDB — so the same dbt models run unchanged when Snowflake
arrives?
```

## Prompt 3 — narrowing: Snowflake is now available (Segment 2, shot 2.5)

```
We now have a live Snowflake account. Update the plan to target Snowflake as
the production engine while keeping DuckDB as the free local/CI engine, with
credentials supplied only via environment variables — never hardcoded.
```

## Prompt 4 — narrowing: representative samples + parallel validation (Segment 2, shot 2.6)

```
Do NOT migrate every job. Migrate 2-3 representative samples per technology
pattern (BTEQ, SAS, Informatica, DataStage), each wrapped in full
before/after golden-parity validation against the legacy outputs. Structure
the work as one sequential foundation session followed by independent
workstreams that can run in separate parallel Devin sessions without editing
the same files.
```

---

## Prompt 5 — the Agent-mode prompt (Segment 3 provenance — pre-run, do not re-run)

This is the (abridged) initial prompt of the already-completed session:
<https://partner-workshops.devinenterprise.com/sessions/a54e56721eb54a2fbcab7457cb5de42d?tab=information%3Aevent-01a036c3485276d18bbc21be5fd5a136>

The full text (Sessions 0 + A–D) is visible as the session's first message —
show it on screen rather than pasting it. Opening paragraph and the two
sections the demo's validation slice covers:

```
Repository: `SachetCognition/albion-insurance-data-estate`. Do NOT migrate
every job. Migrate 2-3 representative samples per technology pattern, each
wrapped in full before/after golden-parity validation, targeting the live
Snowflake instance (account identifier `tojgonb-sf03144`, org `tojgonb`,
account `sf03144`) while keeping DuckDB as the free local/CI engine.
SECURITY: never hardcode Snowflake credentials; use env vars / key-pair auth.

This work is split into a mandatory sequential foundation session followed by
four independent workstreams that can each be executed in a SEPARATE PARALLEL
Devin session. Structure the repo so the parallel sessions never edit the
same files.

=== SESSION 0 (RUN FIRST, ALONE — foundation) ===
Create top-level `transform/` dbt project:
- `dbt_project.yml`, `packages.yml` (`dbt_utils`), `requirements.txt`
  (`dbt-core`, `dbt-snowflake`, `dbt-duckdb`, `sqlfluff`).
- `profiles.yml` with two targets: default `duckdb` (local file) and
  `snowflake` (env vars only). Add `.env.example` and `.gitignore`.
- `transform/snowflake_setup.sql` (idempotent): XS warehouse
  AUTO_SUSPEND=60/AUTO_RESUME, databases `RAW`, `GOLDEN`, role `TRANSFORMER`.
- Seeds: `data/01_source_tables/*.csv` into RAW; `data/02_bteq_staging/*.csv`
  and `data/03_sas_data_products/*.csv` into GOLDEN as the immutable "before"
  baselines.
- Shared canonical macros (standardise_postcode, julian_to_date,
  earned_premium, party crosswalk) and a reusable `assert_golden_parity`
  reconciliation test macro.
- `.sqlfluff` with `dialect = snowflake`.
Verification: `dbt build` passes on DuckDB with zero credentials, and
`dbt build -t snowflake` passes on the live instance.

=== SESSION A (PARALLEL — Teradata BTEQ) ===
Under `models/staging/bteq/`, port `teradata/bteq/01_stg_customer_360.bteq`,
`04_stg_policy_360.bteq`, `06_stg_earned_premium.bteq` into Snowflake SQL.
Consume the shared postcode/date/earned-premium macros — do NOT redefine
them. Add before/after golden-parity tests via `assert_golden_parity`,
generic tests (accepted_values POLICY_STATUS, not_null/unique keys), and
document intentional converged-rule diffs.
```

# Demo storyboard — DeepWiki → Ask Devin → Agent mode → Validation

Target length: **2–3 minutes**. Four segments, each with a fixed shot-list so
every take is identical. Record with an external screen recorder
(Loom / OBS / QuickTime) — see `recording_setup.md` for staging.

All prompts referenced below are verbatim in `prompts.md`.

---

## Segment 1 — DeepWiki: the legacy estate (~20s, 0:00–0:20)

**Tab:** DeepWiki page for `SachetCognition/albion-insurance-data-estate`.

| Shot | Action | Narration cue |
|------|--------|---------------|
| 1.1 | Open the DeepWiki architecture/overview page (pre-loaded). | "This is Albion's legacy insurance data estate…" |
| 1.2 | Slow scroll through the architecture diagram / component list. | "…Teradata warehouse fed by BTEQ scripts, Informatica PowerCenter and DataStage ETL, SAS analytics, and mainframe/AS-400 feeds." |
| 1.3 | Pause on the topology/integration section (Life Bridge, GoldenGate, nightly batch). | "Decades of accumulated pipelines — the question is how to modernise it." |

---

## Segment 2 — Ask Devin: from question to plan (~40s, 0:20–1:00)

**Tab:** Ask Devin for this repo.

| Shot | Action | Narration cue |
|------|--------|---------------|
| 2.1 | Paste **Prompt 1** (modernisation question) and submit. | "We ask Devin how to modernise this estate." |
| 2.2 | Show the answer's **technology-mapping table** (Teradata/BTEQ → Snowflake SQL + dbt, Informatica/DataStage → dbt models, SAS → dbt Python/Snowpark). | "It maps every legacy technology to a modern target…" |
| 2.3 | Scroll to the **phased roadmap** and generated plan. | "…and proposes a phased roadmap." |
| 2.4 | Paste **Prompt 2** (no Snowflake yet → DuckDB) — show the answer adapting to a zero-credential local engine. | "No Snowflake yet? It adapts the plan to DuckDB." |
| 2.5 | Paste **Prompt 3** (Snowflake now available) — show the dual-target answer. | "Once Snowflake is available, both engines run side by side." |
| 2.6 | Paste **Prompt 4** (narrow scope: 2–3 samples per pattern, before/after validation, parallel sessions) — show the resulting execution plan. | "We narrow to representative samples with golden-parity validation, executed in parallel sessions." |

---

## Segment 3 — Agent mode: the pre-run session (~50s, 1:00–1:50)

**IMPORTANT:** this segment uses an **already-completed** Devin session — we do
NOT run a fresh agent live. Say this on camera: *"Rather than waiting on a live
run, here's the session that already executed this plan."*

**Tab (canonical URL, pre-loaded):**
<https://partner-workshops.devinenterprise.com/sessions/a54e56721eb54a2fbcab7457cb5de42d?tab=information%3Aevent-01a036c3485276d18bbc21be5fd5a136>

| Shot | Action | Narration cue |
|------|--------|---------------|
| 3.1 | Show the session's initial prompt (Session 0 + parallel Sessions A–D structure). | "The full plan went in as one Agent-mode prompt: a sequential foundation session, then four parallel workstreams." |
| 3.2 | Scroll the timeline: Session 0 foundation completes (`transform/` dbt project, DuckDB 28/28, live Snowflake 28/28) → PR #8. | "Session 0 built the dbt foundation and verified it on both engines." |
| 3.3 | Continue scrolling: the four parallel sessions launch (A: BTEQ, B: SAS, C: Informatica, D: DataStage) and land PRs #9–#12. | "Then four Devin sessions ran in parallel, one per legacy technology." |
| 3.4 | Land on the committed output: the PR links / final message (216/216 tests passing on the integrated branch). | "Every migrated job passed before/after golden-parity validation." |

---

## Segment 4 — Validation: deterministic green (~30s, 1:50–2:20)

Two options — pick ONE per take:

**Option A (recommended, fully deterministic):** local terminal.

| Shot | Action | Narration cue |
|------|--------|---------------|
| 4.1 | In a pre-staged terminal at the repo root, run `./demo/run_validation.sh`. | "The migrated models validate locally on DuckDB — zero credentials." |
| 4.2 | Let it run to completion (~30s): seeds + models + parity tests, then sqlfluff lint. | "Seeds load, models build, and every golden-parity test compares the new output row-for-row against the legacy baselines." |
| 4.3 | End on the final `PASS=… ERROR=0` summary and `All Finished!` lint line. | "All green — identical output on every take." |

**Option B:** stay in the Segment 3 session and show its recorded validation
evidence (the attached post-migration recording / PR #8 comment with the
216/216 Snowflake build and Snowsight row counts).

---

## Timing summary

| Segment | Content | Duration | Cumulative |
|---------|---------|----------|------------|
| 1 | DeepWiki legacy estate | ~20s | 0:20 |
| 2 | Ask Devin question → plan | ~40s | 1:00 |
| 3 | Pre-run Agent session | ~50s | 1:50 |
| 4 | Deterministic validation | ~30s | 2:20 |

# Albion data-estate assessment tooling (ADEM-1)

Scans this repository and generates a single self-contained HTML assessment
report at
[`docs/assessment/albion_data_estate_assessment.html`](../../docs/assessment/albion_data_estate_assessment.html),
plus machine-readable JSON/CSV under `docs/assessment/data/`.

**This tooling is read-only.** It never writes outside `docs/assessment/`.

## Run it

```bash
python3 tools/assessment/run_assessment.py
```

Python 3.8+, standard library only — there is no `requirements.txt` because
there are no third-party dependencies.

The two stages can also be run separately:

```bash
# 1. Scan the estate -> docs/assessment/data/*.json|csv
python3 tools/assessment/estate_scan.py

# 2. Render the report -> docs/assessment/albion_data_estate_assessment.html
python3 tools/assessment/render_report.py
```

Useful flags:

| Flag / env var | Effect |
|---|---|
| `--repo-root PATH` | Scan a different checkout (default: repo root) |
| `--out-dir PATH` | Write the structured data elsewhere |
| `--allow-unresolved` | Warn instead of failing when an evidence probe no longer matches |
| `ALBION_ASSESSMENT_TIMESTAMP=...` | Pin `generated_at_utc` so regeneration is byte-identical |

## Files

| File | Role |
|---|---|
| `findings_catalogue.py` | The analyst layer: findings, severities, business impact, the attribute-overlap matrix, the recommended canonical model and the target-architecture recommendation. Holds **no line numbers** — only evidence *probes*. |
| `estate_scan.py` | The scanner: parses the estate's own artefacts and resolves every probe into a real `path:line` citation with a snippet. Writes the JSON/CSV intermediates. |
| `render_report.py` | Renders the JSON into one HTML file with all CSS and JS inlined. |
| `run_assessment.py` | Convenience wrapper: scan, then render. |

## How evidence stays honest

The catalogue never records a line number. Each claim declares probes of the
form `(path, literal_snippet)`, and `estate_scan.py` locates that snippet in
the working tree at scan time to produce the citation. If a probe no longer
matches — because a file moved or its wording changed — the scan prints the
unresolved probes to stderr and **exits non-zero**, so the published report can
never cite a reference that has drifted away from the code.

What is derived by parsing rather than asserted:

- the feed inventory (markdown tables in `docs/feed_inventory.md`);
- the DQ registry with its registered-vs-actual implementation counts
  (`dq_rules/dq_rules_registry.csv`);
- Informatica workflows, folders, mappings and transformations
  (XML in `informatica/XML/`);
- BTEQ / SAS / JCL / CL / PL/SQL asset inventory with their declared headers;
- the schedule inventory (Control-M XML, the prod crontab, AS/400 `ADDJOBSCDE`,
  the DataStage Director schedule);
- identifier-scheme occurrence and file counts across the working tree;
- per-feed lineage lanes, derived from which artefacts reference each feed's
  distinctive tokens;
- the competing business definitions quoted from the four glossaries.

## Output

| Path | Contents |
|---|---|
| `docs/assessment/albion_data_estate_assessment.html` | The report. Self-contained: no external CSS, fonts, images or scripts. |
| `docs/assessment/data/assessment_findings.json` | Full structured dataset. |
| `docs/assessment/data/findings.csv` | One row per finding with severity and evidence refs. |
| `docs/assessment/data/feed_inventory.csv` | Inventoried feeds plus the feeds found only in code. |
| `docs/assessment/data/attribute_overlap_matrix.csv` | One row per attribute × producing system. |
| `docs/assessment/data/dq_rule_drift.csv` | Registered vs actual DQ rule implementations. |
| `docs/assessment/data/schedule_inventory.csv` | Every job across the four schedulers. |

## Extending it

Add a finding to `FINDINGS` in `findings_catalogue.py` with at least one
evidence probe, then re-run `run_assessment.py`. If the probe does not resolve,
the scan fails and tells you which literal it could not find.

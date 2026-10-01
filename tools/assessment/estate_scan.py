#!/usr/bin/env python3
"""Scan the Albion legacy data estate and emit structured assessment data.

The scanner does three things:

1. **Parses** the estate's own artefacts (feed inventory, DQ registry,
   glossaries, Informatica XML, BTEQ/SAS headers, Control-M and cron) so the
   inventory sections of the report are derived from the repository rather
   than transcribed by hand.
2. **Resolves** every evidence probe declared in :mod:`findings_catalogue`
   into a real ``path:line`` citation plus the matching source snippet. Any
   probe that no longer matches is reported as unresolved and the scan exits
   non-zero, so the report can never cite a stale reference.
3. **Writes** a JSON intermediate plus machine-readable CSV side outputs.

Standard library only. Usage::

    python3 tools/assessment/estate_scan.py [--repo-root .] [--out-dir docs/assessment/data]
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import findings_catalogue as cat  # noqa: E402

PROTECTED_DIRS = [
    "informatica", "sas", "teradata", "datastage", "mainframe", "as400_life",
    "api_legacy", "orchestration", "dq_rules", "glossary", "data",
]

IDENTITY_SCHEMES = [
    {
        "scheme": "CUSTOMER_ID",
        "owner_system": "APF core banking (Teradata CORE_BANKING_DB)",
        "grain": "Banking customer",
        "format": "INTEGER",
        "crosswalk": "PARTY.LEGACY_CUSTOMER_ID (~55% populated, no RI)",
        "token": r"\bCUSTOMER_ID\b",
    },
    {
        "scheme": "PARTY_ID",
        "owner_system": "POLARIS PAS / Oracle MDM hub",
        "grain": "Insurance party (person or organisation)",
        "format": "CHAR(8), 'P' + 7 digits",
        "crosswalk": "REF_DB.XREF_CLIENT_PARTY (manual) to CLIENT_NO",
        "token": r"\bPARTY_ID\b",
    },
    {
        "scheme": "CLIENT_NO",
        "owner_system": "LEGACY_PAS (mainframe VSAM)",
        "grain": "Legacy P&C client",
        "format": "PIC 9(10) zero-padded",
        "crosswalk": "REF_DB.XREF_CLIENT_PARTY (manual) to PARTY_ID",
        "token": r"\bCLIENT[_-]NO\b",
    },
    {
        "scheme": "customer_ref",
        "owner_system": "SOAP PolicyInquiryService / Oracle ODS",
        "grain": "Whatever the NVL resolved to",
        "format": "VARCHAR — legacy CUSTOMER_ID or PARTY_ID",
        "crosswalk": "None — consumers parse the prefix",
        "token": r"customer_?ref",
    },
    {
        "scheme": "LIFE_POLICY_ID",
        "owner_system": "LIFE400 (AS/400, Provident Mutual)",
        "grain": "Life contract, used as a person proxy",
        "format": "CHAR(12), 'PM' prefixed",
        "crosswalk": "None — name+DOB fuzzy match in a lost-source DataStage job",
        "token": r"LIFE_POLICY_ID|\bPOLID\b",
    },
    {
        "scheme": "MKTG_CUST_ID",
        "owner_system": "Retail partner loyalty files / DataStage marts",
        "grain": "Partner-issued customer",
        "format": "5-digit partner-issued integer",
        "crosswalk": "None — ad hoc name+email dedupe in the marts",
        "token": r"MKTG_CUST_ID|CustomerID",
    },
]

TEXT_EXTENSIONS = {
    ".md", ".sql", ".bteq", ".sas", ".xml", ".wsdl", ".csv", ".cfg", ".txt",
    ".sh", ".ksh", ".jcl", ".cpy", ".clle", ".cblle", ".pf", ".dspf", ".prtf",
    ".par", ".dsx", ".properties", ".yml", ".yaml", ".json", ".py",
}


# ---------------------------------------------------------------------------
# Low-level helpers
# ---------------------------------------------------------------------------
def read_text(repo_root: str, rel_path: str) -> str:
    with open(os.path.join(repo_root, rel_path), "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def line_of_offset(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def resolve_probe(repo_root, rel_path, needle, note=None, unresolved=None):
    """Turn ``(path, needle)`` into a concrete citation against the working tree."""
    full = os.path.join(repo_root, rel_path)
    if not os.path.isfile(full):
        if unresolved is not None:
            unresolved.append({"path": rel_path, "needle": needle, "reason": "file not found"})
        return None
    text = read_text(repo_root, rel_path)
    idx = text.find(needle)
    if idx < 0:
        if unresolved is not None:
            unresolved.append({"path": rel_path, "needle": needle, "reason": "needle not found"})
        return None
    start_line = line_of_offset(text, idx)
    end_line = line_of_offset(text, idx + len(needle) - 1)
    lines = text.splitlines()
    snippet = "\n".join(lines[start_line - 1:end_line]).strip()
    if len(snippet) > 400:
        snippet = snippet[:397] + "..."
    citation = {
        "path": rel_path,
        "line_start": start_line,
        "line_end": end_line,
        "ref": "%s:%d" % (rel_path, start_line) if start_line == end_line
               else "%s:%d-%d" % (rel_path, start_line, end_line),
        "snippet": snippet,
    }
    if note:
        citation["note"] = note
    return citation


def resolve_probes(repo_root, probes, unresolved):
    out = []
    for probe in probes:
        rel_path, needle = probe[0], probe[1]
        note = probe[2] if len(probe) > 2 else None
        citation = resolve_probe(repo_root, rel_path, needle, note, unresolved)
        if citation:
            out.append(citation)
    return out


GENERATED_PREFIXES = ("tools/assessment/", "docs/assessment/")


def iter_repo_files(repo_root):
    """Yield estate artefacts, excluding this tooling and its own outputs."""
    for dirpath, dirnames, filenames in os.walk(repo_root):
        dirnames[:] = [d for d in dirnames if d not in (".git", "__pycache__")]
        for name in filenames:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, repo_root).replace(os.sep, "/")
            if rel.startswith(GENERATED_PREFIXES):
                continue
            yield rel


# ---------------------------------------------------------------------------
# Parsers over the estate's own artefacts
# ---------------------------------------------------------------------------
def parse_markdown_tables(text):
    """Return every pipe-table in a markdown document as a list of dict rows."""
    tables, rows, header = [], [], None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("|") and line.endswith("|"):
            cells = [c.strip() for c in line.strip("|").split("|")]
            if header is None:
                header = cells
                rows = []
            elif set("".join(cells)) <= set("-: "):
                continue
            else:
                rows.append(dict(zip(header, cells)))
        else:
            if header and rows:
                tables.append({"header": header, "rows": rows})
            header, rows = None, []
    if header and rows:
        tables.append({"header": header, "rows": rows})
    return tables


def parse_feed_inventory(repo_root, unresolved):
    rel = "docs/feed_inventory.md"
    text = read_text(repo_root, rel)
    feeds = []
    for table in parse_markdown_tables(text):
        if "Feed" not in table["header"]:
            continue
        for row in table["rows"]:
            label = row.get("Feed", "")
            m = re.match(r"(FD-\d+)\s*(.*)", label)
            if not m:
                continue
            feed_id, name = m.group(1), m.group(2).strip()
            citation = resolve_probe(repo_root, rel, label, None, unresolved)
            feeds.append({
                "feed_id": feed_id,
                "name": name,
                "source_system": row.get("Source", ""),
                "technology": row.get("Tech", ""),
                "schedule": row.get("Frequency", ""),
                "consumers": row.get("Consumers", ""),
                "owner": row.get("Owner", ""),
                "overlapping_attributes": row.get("Overlapping attributes", ""),
                "evidence": [citation] if citation else [],
            })
    feeds.sort(key=lambda f: f["feed_id"])
    return feeds


def parse_dq_registry(repo_root):
    rel = "dq_rules/dq_rules_registry.csv"
    text = read_text(repo_root, rel)
    lines = text.splitlines()
    rules = []
    for row in csv.DictReader(lines):
        rule_id = row["rule_id"]
        line_no = next((i + 1 for i, l in enumerate(lines) if l.startswith(rule_id + ",")), None)
        registered = row["implementations_registered"]
        actual = row["implementations_actual"]
        n_registered = 0 if registered.strip().lower() == "none" else len(
            [p for p in registered.split(";") if p.strip()])
        n_actual = 0 if actual.strip().lower() in ("none", "none active") else len(
            [p for p in actual.split(";") if p.strip()])
        rules.append({
            "rule_id": rule_id,
            "rule_name": row["rule_name"],
            "business_definition": row["business_definition"],
            "implementations_registered": registered,
            "implementations_actual": actual,
            "registered_count": n_registered,
            "actual_count": n_actual,
            "undercount": max(0, n_actual - n_registered),
            "owner": row["owner"],
            "status": row["status"],
            "evidence": {"path": rel, "line_start": line_no, "ref": "%s:%s" % (rel, line_no)},
        })
    return rules


def parse_informatica(repo_root):
    workflows = []
    xml_dir = os.path.join(repo_root, "informatica", "XML")
    if not os.path.isdir(xml_dir):
        return workflows
    for name in sorted(os.listdir(xml_dir)):
        if not name.endswith(".xml"):
            continue
        rel = "informatica/XML/" + name
        text = read_text(repo_root, rel)
        try:
            root = ET.fromstring(text)
        except ET.ParseError:
            root = None
        transformations, sources, targets = [], [], []
        workflow_name, schedule, folder, mapping = None, "", "", ""
        if root is not None:
            for node in root.iter():
                tag = node.tag.upper()
                if tag == "FOLDER":
                    folder = node.get("NAME", folder)
                elif tag == "WORKFLOW":
                    workflow_name = node.get("NAME", workflow_name)
                    schedule = node.get("DESCRIPTION", "") or schedule
                elif tag == "MAPPING":
                    mapping = node.get("NAME", mapping)
                elif tag == "TRANSFORMATION":
                    transformations.append({
                        "name": node.get("NAME", ""),
                        "type": node.get("TYPE", ""),
                        "description": node.get("DESCRIPTION", ""),
                    })
                elif tag == "SOURCE":
                    sources.append(node.get("NAME") or node.get("DBDNAME") or "")
                elif tag == "TARGET":
                    targets.append(node.get("NAME", ""))
        workflows.append({
            "engine": "Informatica PowerCenter 10.5",
            "artefact": rel,
            "folder": folder,
            "mapping": mapping,
            "name": workflow_name or name.replace(".xml", ""),
            "transformations": transformations,
            "sources": [s for s in sources if s],
            "targets": [t for t in targets if t],
            "schedule": schedule,
            "line_count": text.count("\n") + 1,
        })
    return workflows


HEADER_KEYS = ("Purpose", "Source", "Target", "Schedule", "Sources", "Targets",
               "Downstream", "Consumers", "Inputs", "Output", "Outputs")


def parse_header_comments(text, limit=40):
    meta = {}
    for line in text.splitlines()[:limit]:
        stripped = line.strip().lstrip("/*-#;! ").rstrip("*/ ").strip()
        for key in HEADER_KEYS:
            if stripped.lower().startswith(key.lower() + ":"):
                value = stripped.split(":", 1)[1].strip()
                if value:
                    meta.setdefault(key.rstrip("s") if key.endswith("s") else key, value)
    return meta


def parse_script_estate(repo_root):
    """Inventory BTEQ, SAS, JCL, CL, DDL and shell assets with their headers."""
    engines = {
        "teradata/bteq": ("Teradata BTEQ", (".bteq", ".sh")),
        "teradata/ddl": ("Teradata DDL", (".sql",)),
        "sas": ("SAS 9.4", (".sas", ".sh")),
        "mainframe": ("Mainframe (COBOL/JCL/VSAM)", (".jcl", ".cpy", ".md")),
        "as400_life": ("AS/400 LIFE400", (".clle", ".cblle", ".pf", ".md", ".dspf")),
        "api_legacy": ("Oracle PL/SQL + SOAP", (".sql", ".wsdl")),
        "orchestration": ("Scheduling", (".xml", ".txt", ".sh", ".cfg")),
        "datastage": ("IBM DataStage 9.1", (".dsx", ".md")),
        "dq_rules": ("DQ controls", (".sql", ".csv")),
    }
    assets = []
    for prefix, (engine, exts) in engines.items():
        base = os.path.join(repo_root, prefix)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if d != ".git"]
            for name in sorted(filenames):
                if exts and not name.endswith(exts):
                    continue
                rel = os.path.relpath(os.path.join(dirpath, name), repo_root).replace(os.sep, "/")
                text = read_text(repo_root, rel)
                assets.append({
                    "engine": engine,
                    "artefact": rel,
                    "name": name,
                    "line_count": text.count("\n") + 1,
                    "header": parse_header_comments(text),
                })
    assets.sort(key=lambda a: a["artefact"])
    return assets


def parse_schedules(repo_root, unresolved):
    entries = []
    ctm_rel = "orchestration/controlm/ALBION_DWH_DAILY.xml"
    ctm_text = read_text(repo_root, ctm_rel)
    root = ET.fromstring(ctm_text)
    for job in root.iter("JOB"):
        name = job.get("JOBNAME", "")
        citation = resolve_probe(repo_root, ctm_rel, 'JOBNAME="%s"' % name, None, unresolved)
        entries.append({
            "scheduler": "Control-M",
            "job": name,
            "description": job.get("DESCRIPTION", ""),
            "command": job.get("CMDLINE", ""),
            "time": " ".join(filter(None, [
                job.get("TIMEFROM", ""), job.get("TIMETO", ""),
                "cyclic %s" % job.get("INTERVAL") if job.get("CYCLIC") == "Y" else "",
                job.get("MONTHDAYS", ""),
            ])).strip(),
            "dependencies": [c.get("NAME", "") for c in job.iter("INCOND")],
            "evidence": [citation] if citation else [],
        })
    cron_rel = "orchestration/cron/crontab_prod.txt"
    cron_text = read_text(repo_root, cron_rel)
    for i, line in enumerate(cron_text.splitlines(), start=1):
        if not line.strip() or line.strip().startswith("#"):
            continue
        parts = line.split(None, 5)
        if len(parts) < 6:
            continue
        command = parts[5]
        comment = ""
        if "#" in command:
            command, comment = command.split("#", 1)
        entries.append({
            "scheduler": "cron (albetl01)",
            "job": command.strip().split()[0].rsplit("/", 1)[-1],
            "description": comment.strip(),
            "command": command.strip(),
            "time": " ".join(parts[:5]),
            "dependencies": [],
            "evidence": [{"path": cron_rel, "line_start": i, "line_end": i,
                          "ref": "%s:%d" % (cron_rel, i), "snippet": line.strip()}],
        })
    for rel, needle, job, desc in [
        ("as400_life/LIFE400/QCLSRC/DLYUPD.clle", "ADDJOBSCDE", "DLYUPD",
         "AS/400 job scheduler entry — weekly, described as nightly"),
        ("orchestration/cron/crontab_prod.txt", "triple-scheduled", "LIFE_POLICY_LOAD",
         "DataStage Director scheduler (third schedule for the same job)"),
    ]:
        citation = resolve_probe(repo_root, rel, needle, None, unresolved)
        if citation:
            entries.append({
                "scheduler": "AS/400 ADDJOBSCDE" if "DLYUPD" in job else "DataStage Director",
                "job": job, "description": desc, "command": "", "time": "",
                "dependencies": [], "evidence": [citation],
            })
    return entries


def parse_glossary_conflicts(repo_root, unresolved):
    """Extract the competing business definitions from the four glossaries."""
    specs = [
        ("Active policy", "Underwriting", "glossary/underwriting_data_dictionary.csv",
         "Policy with status IF or RN"),
        ("Active policy", "Finance", "glossary/finance_data_dictionary.csv",
         "at least one premium collection in the last 45 days"),
        ("Active policy", "Claims MI", "glossary/claims_glossary.md",
         "any policy with at least one OPEN or REOPENED claim"),
        ("Active policy", "Life Operations", "glossary/life_operations_glossary.md",
         "CNTRSTS in ('AC','GR','RS')"),
        ("Earned premium", "Finance", "glossary/finance_data_dictionary.csv",
         "1/12ths"),
        ("Earned premium", "Actuarial", "glossary/actuarial_definitions.md",
         "365ths"),
        ("Earned premium", "Billing recon", "informatica/XML/wf_BILLING_PREMIUM_RECON.xml",
         "1/24ths"),
        ("Premium in force", "Life Operations", "glossary/life_operations_glossary.md",
         "Annualised Premium In Force"),
        ("Risk score", "Claims SIU", "glossary/claims_glossary.md",
         "FRAUD_SCORE >= 650 (SIU 0\u20131000 scale)"),
        ("Risk score", "APF banking", "glossary/claims_glossary.md",
         "confused with the APF banking RISK_SCORE (0\u20131 probability)"),
        ("Incurred date", "Claims MI", "glossary/claims_glossary.md",
         "Claims MI use **LOSS_DT**"),
        ("Incurred date", "Finance", "glossary/claims_glossary.md",
         "recognise incurred movements on **NOTIFICATION_DT**"),
        ("Customer / policyholder", "Finance", "glossary/finance_data_dictionary.csv",
         "CUSTOMER_ID"),
        ("Customer / policyholder", "Underwriting", "glossary/underwriting_data_dictionary.csv",
         "PARTY_ID"),
        ("Customer / policyholder", "Life Operations", "glossary/life_operations_glossary.md",
         "INSNAME free text on POLMST. No party key."),
        ("Customer / policyholder", "Claims MI", "glossary/claims_glossary.md",
         "**Claimant** — CLAIMANT_PARTY_ID"),
    ]
    conflicts = {}
    for term, community, rel, needle in specs:
        citation = resolve_probe(repo_root, rel, needle, None, unresolved)
        if not citation:
            continue
        conflicts.setdefault(term, []).append({
            "community": community,
            "definition": citation["snippet"],
            "evidence": citation,
        })
    return [{"term": term, "definitions": defs} for term, defs in conflicts.items()]


def scan_identity_schemes(repo_root):
    schemes = []
    files = [f for f in iter_repo_files(repo_root)
             if os.path.splitext(f)[1].lower() in TEXT_EXTENSIONS]
    cache = {}
    for f in files:
        try:
            cache[f] = read_text(repo_root, f)
        except OSError:
            continue
    for spec in IDENTITY_SCHEMES:
        pattern = re.compile(spec["token"])
        hits, occurrences = [], 0
        for rel, text in cache.items():
            found = pattern.findall(text)
            if found:
                hits.append(rel)
                occurrences += len(found)
        entry = dict(spec)
        entry["file_count"] = len(hits)
        entry["occurrence_count"] = occurrences
        entry["files"] = sorted(hits)[:12]
        schemes.append(entry)
    return schemes


def build_lineage(repo_root, feeds):
    """Derive source -> ingest -> staging -> product -> consumption edges per feed.

    Layer membership is inferred from the top-level directory of every file that
    references the feed's distinctive tokens, so the map reflects the code.
    """
    layer_by_dir = {
        "mainframe": "Source / extract",
        "as400_life": "Source / extract",
        "datastage": "Ingest",
        "informatica": "Ingest / transform",
        "teradata": "Staging & warehouse",
        "sas": "Analytics / data product",
        "api_legacy": "Consumption",
        "dq_rules": "Controls",
        "orchestration": "Scheduling",
        "docs": "Documentation",
        "glossary": "Documentation",
        "data": "Sample data",
    }
    tokens_by_feed = {
        "FD-001": ["PLCYMSTR", "PLCYEXTR", "wf_POLICY_MASTER_DAILY", "04_stg_policy_360"],
        "FD-002": ["POLARIS", "POLICY_ADMIN_DB"],
        "FD-003": ["GUIDEWIRE", "Guidewire", "wf_CLAIMS_FNOL_INTRADAY"],
        "FD-004": ["LEGACY_CLM", "CLMHIST"],
        "FD-005": ["bdx_transfer", "BORDEREAUX", "REINSURANCE_DB"],
        "FD-006": ["CORE_BANKING_DB", "STG_CUSTOMER_360"],
        "FD-007": ["PREMIUM_TRANSACTIONS", "wf_BILLING_PREMIUM_RECON", "06_stg_earned_premium"],
        "FD-008": ["BUREAU", "bureau"],
        "FD-009": ["legacy_shared_services", "EHRP"],
        "FD-010": ["POLMSTEX", "LIFE_POLICY_LOAD", "LIFE_DB"],
        "FD-011": ["Bouns", "RETAIL_DATA_MART", "MKTG_CUST_ID"],
    }
    files = [f for f in iter_repo_files(repo_root)
             if os.path.splitext(f)[1].lower() in TEXT_EXTENSIONS]
    cache = {f: read_text(repo_root, f) for f in files}
    lineage = []
    for feed in feeds:
        tokens = tokens_by_feed.get(feed["feed_id"], [])
        layers = {}
        for rel, text in cache.items():
            if "/" not in rel or not any(tok in text for tok in tokens):
                continue
            top = rel.split("/", 1)[0]
            layer = layer_by_dir.get(top, "Other")
            if layer in ("Documentation", "Sample data"):
                continue
            layers.setdefault(layer, []).append(rel)
        ordered = ["Source / extract", "Ingest", "Ingest / transform",
                   "Staging & warehouse", "Analytics / data product",
                   "Consumption", "Controls", "Scheduling", "Other"]
        lineage.append({
            "feed_id": feed["feed_id"],
            "name": feed["name"],
            "tokens": tokens,
            "layers": [{"layer": l, "artefacts": sorted(set(layers[l]))}
                       for l in ordered if l in layers],
        })
    return lineage


# ---------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------
def git_commit(repo_root):
    try:
        out = subprocess.run(["git", "-C", repo_root, "rev-parse", "--short", "HEAD"],
                             capture_output=True, text=True, timeout=20)
        return out.stdout.strip() or "unknown"
    except (OSError, subprocess.SubprocessError):
        return "unknown"


def build_dataset(repo_root):
    unresolved = []
    feeds = parse_feed_inventory(repo_root, unresolved)

    findings = []
    for finding in cat.FINDINGS:
        item = dict(finding)
        item["evidence"] = resolve_probes(repo_root, finding["evidence"], unresolved)
        item["category_title"] = next(c["title"] for c in cat.CATEGORIES
                                      if c["id"] == finding["category"])
        findings.append(item)

    matrix = []
    for row in cat.ATTRIBUTE_MATRIX:
        producers = []
        for producer in row["producers"]:
            entry = dict(producer)
            entry["evidence"] = resolve_probe(repo_root, producer["evidence"][0],
                                              producer["evidence"][1], None, unresolved)
            producers.append(entry)
        matrix.append({"attribute": row["attribute"], "canonical": row["canonical"],
                       "producers": producers})

    unlisted = []
    for feed in cat.UNLISTED_FEEDS:
        item = dict(feed)
        item["evidence"] = resolve_probes(repo_root, feed["evidence"], unresolved)
        unlisted.append(item)

    dataset = {
        "meta": {
            "generated_at_utc": os.environ.get(
                "ALBION_ASSESSMENT_TIMESTAMP",
                datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")),
            "repo_root": os.path.basename(os.path.abspath(repo_root)),
            "git_commit": git_commit(repo_root),
            "scanned_file_count": sum(1 for _ in iter_repo_files(repo_root)),
            "ticket": "ADEM-1",
        },
        "exec_summary": cat.EXEC_SUMMARY,
        "categories": cat.CATEGORIES,
        "findings": findings,
        "severity_order": cat.SEVERITY_ORDER,
        "feeds": feeds,
        "unlisted_feeds": unlisted,
        "lineage": build_lineage(repo_root, feeds),
        "pipelines": {
            "informatica": parse_informatica(repo_root),
            "assets": parse_script_estate(repo_root),
        },
        "schedules": parse_schedules(repo_root, unresolved),
        "identity_schemes": scan_identity_schemes(repo_root),
        "dq_registry": parse_dq_registry(repo_root),
        "glossary_conflicts": parse_glossary_conflicts(repo_root, unresolved),
        "attribute_matrix": matrix,
        "target_domains": cat.TARGET_DOMAINS,
        "platform_recommendation": cat.PLATFORM_RECOMMENDATION,
        "unresolved_probes": unresolved,
    }

    counts = {}
    for finding in findings:
        counts[finding["severity"]] = counts.get(finding["severity"], 0) + 1
    dataset["severity_counts"] = counts
    return dataset


def write_csv(path, header, rows):
    with open(path, "w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(header)
        writer.writerows(rows)


def write_side_outputs(dataset, out_dir):
    write_csv(
        os.path.join(out_dir, "feed_inventory.csv"),
        ["feed_id", "name", "source_system", "technology", "schedule", "consumers",
         "owner", "overlapping_attributes", "evidence"],
        [[f["feed_id"], f["name"], f["source_system"], f["technology"], f["schedule"],
          f["consumers"], f["owner"], f["overlapping_attributes"],
          "; ".join(e["ref"] for e in f["evidence"])] for f in dataset["feeds"]]
        + [[u["id"], u["name"], "NOT IN INVENTORY", u["tech"], "", "", "", u["why_missing"],
            "; ".join(e["ref"] for e in u["evidence"])] for u in dataset["unlisted_feeds"]],
    )
    write_csv(
        os.path.join(out_dir, "findings.csv"),
        ["finding_id", "category", "category_title", "severity", "title", "evidence_refs"],
        [[f["id"], f["category"], f["category_title"], f["severity"], f["title"],
          "; ".join(e["ref"] for e in f["evidence"])] for f in dataset["findings"]],
    )
    write_csv(
        os.path.join(out_dir, "attribute_overlap_matrix.csv"),
        ["canonical_attribute", "canonical_target", "producing_system", "physical_name",
         "physical_format", "derivation", "evidence"],
        [[row["attribute"], row["canonical"], p["system"], p["physical"], p["format"],
          p["derivation"], p["evidence"]["ref"] if p["evidence"] else ""]
         for row in dataset["attribute_matrix"] for p in row["producers"]],
    )
    write_csv(
        os.path.join(out_dir, "dq_rule_drift.csv"),
        ["rule_id", "rule_name", "status", "owner", "registered_count", "actual_count",
         "undercount", "implementations_actual", "evidence"],
        [[r["rule_id"], r["rule_name"], r["status"], r["owner"], r["registered_count"],
          r["actual_count"], r["undercount"], r["implementations_actual"],
          r["evidence"]["ref"]] for r in dataset["dq_registry"]],
    )
    write_csv(
        os.path.join(out_dir, "schedule_inventory.csv"),
        ["scheduler", "job", "time", "description", "command", "dependencies", "evidence"],
        [[s["scheduler"], s["job"], s["time"], s["description"], s["command"],
          "; ".join(s["dependencies"]), "; ".join(e["ref"] for e in s["evidence"])]
         for s in dataset["schedules"]],
    )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    default_root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    parser.add_argument("--repo-root", default=default_root)
    parser.add_argument("--out-dir", default=None,
                        help="defaults to <repo-root>/docs/assessment/data")
    parser.add_argument("--allow-unresolved", action="store_true",
                        help="do not fail when an evidence probe no longer matches")
    args = parser.parse_args(argv)

    repo_root = os.path.abspath(args.repo_root)
    out_dir = args.out_dir or os.path.join(repo_root, "docs", "assessment", "data")
    os.makedirs(out_dir, exist_ok=True)

    dataset = build_dataset(repo_root)

    json_path = os.path.join(out_dir, "assessment_findings.json")
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump(dataset, fh, indent=2, sort_keys=False)
        fh.write("\n")
    write_side_outputs(dataset, out_dir)

    evidence_count = sum(len(f["evidence"]) for f in dataset["findings"])
    print("Scanned %d files at commit %s" % (dataset["meta"]["scanned_file_count"],
                                             dataset["meta"]["git_commit"]))
    print("Findings: %d across %d categories; resolved evidence citations: %d"
          % (len(dataset["findings"]), len(dataset["categories"]), evidence_count))
    print("Feeds: %d inventoried, %d discovered in code but absent from the inventory"
          % (len(dataset["feeds"]), len(dataset["unlisted_feeds"])))
    print("Wrote %s" % json_path)

    if dataset["unresolved_probes"]:
        print("\nUNRESOLVED EVIDENCE PROBES (%d):" % len(dataset["unresolved_probes"]),
              file=sys.stderr)
        for probe in dataset["unresolved_probes"]:
            print("  %s :: %r :: %s" % (probe["path"], probe["needle"], probe["reason"]),
                  file=sys.stderr)
        if not args.allow_unresolved:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

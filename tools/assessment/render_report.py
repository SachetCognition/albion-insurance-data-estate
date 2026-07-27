#!/usr/bin/env python3
"""Render the Albion data-estate assessment report as one self-contained HTML file.

Reads the JSON produced by :mod:`estate_scan` and writes a single HTML document
with all CSS and JavaScript inlined. No fonts, images, scripts or stylesheets
are fetched at runtime, so the report renders offline from the filesystem.

Usage::

    python3 tools/assessment/render_report.py \
        --data docs/assessment/data/assessment_findings.json \
        --out  docs/assessment/albion_data_estate_assessment.html
"""

from __future__ import annotations

import argparse
import html
import json
import os

SEVERITY_CLASS = {"Critical": "sev-critical", "High": "sev-high",
                  "Medium": "sev-medium", "Low": "sev-low"}

CSS = """
:root{
  --bg:#f6f7f9; --panel:#ffffff; --ink:#15202b; --muted:#5b6b7c; --line:#dde3ea;
  --accent:#0b4f6c; --accent-soft:#e8f0f4; --code:#f2f4f7;
  --crit:#8b1a1a; --crit-bg:#fbe9e9; --high:#9a4a06; --high-bg:#fdf0e4;
  --med:#7a6100; --med-bg:#fdf7dd; --low:#2c5f2d; --low-bg:#eaf4ea;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font:15px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
code,pre,.mono{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,"Liberation Mono",monospace}
header.masthead{background:var(--accent);color:#fff;padding:28px 32px}
header.masthead h1{margin:0 0 6px;font-size:26px;letter-spacing:-.2px}
header.masthead .sub{opacity:.85;font-size:14px}
.meta-strip{display:flex;flex-wrap:wrap;gap:18px;margin-top:14px;font-size:12.5px;opacity:.92}
.meta-strip span{background:rgba(255,255,255,.12);padding:4px 10px;border-radius:3px}
.layout{display:flex;align-items:flex-start;gap:24px;max-width:1500px;margin:0 auto;padding:24px}
nav.toc{position:sticky;top:24px;flex:0 0 250px;background:var(--panel);border:1px solid var(--line);
  border-radius:6px;padding:14px 16px;font-size:13.5px;max-height:calc(100vh - 60px);overflow:auto}
nav.toc h2{font-size:11px;text-transform:uppercase;letter-spacing:.09em;color:var(--muted);margin:0 0 8px}
nav.toc a{display:block;color:var(--ink);text-decoration:none;padding:4px 6px;border-radius:4px}
nav.toc a:hover{background:var(--accent-soft);color:var(--accent)}
main{flex:1 1 auto;min-width:0}
section{background:var(--panel);border:1px solid var(--line);border-radius:6px;
  padding:22px 26px;margin-bottom:22px}
section>h2{margin:0 0 4px;font-size:20px;color:var(--accent);letter-spacing:-.2px}
section>p.lede{margin:0 0 16px;color:var(--muted)}
h3{font-size:16px;margin:22px 0 8px}
h4{font-size:14px;margin:16px 0 6px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
table{border-collapse:collapse;width:100%;font-size:13.2px;margin:10px 0 4px}
th,td{border:1px solid var(--line);padding:7px 9px;text-align:left;vertical-align:top}
th{background:var(--accent-soft);color:var(--accent);font-weight:600;position:sticky;top:0}
tbody tr:nth-child(even){background:#fbfcfd}
.scroll{overflow-x:auto}
.badge{display:inline-block;padding:2px 8px;border-radius:11px;font-size:11.5px;font-weight:700;
  letter-spacing:.03em;white-space:nowrap}
.sev-critical{background:var(--crit-bg);color:var(--crit);border:1px solid #eccaca}
.sev-high{background:var(--high-bg);color:var(--high);border:1px solid #eed7bd}
.sev-medium{background:var(--med-bg);color:var(--med);border:1px solid #e8dfae}
.sev-low{background:var(--low-bg);color:var(--low);border:1px solid #c9e0c9}
.pill{display:inline-block;background:var(--accent-soft);color:var(--accent);border-radius:11px;
  padding:2px 9px;font-size:11.5px;margin:0 4px 4px 0}
.cards{display:flex;flex-wrap:wrap;gap:12px;margin:12px 0 4px}
.card{flex:1 1 150px;border:1px solid var(--line);border-radius:6px;padding:12px 14px;background:#fbfcfd}
.card .n{font-size:26px;font-weight:700;line-height:1.1}
.card .l{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.05em}
.finding{border:1px solid var(--line);border-left:4px solid var(--accent);border-radius:5px;
  padding:14px 16px;margin:14px 0;background:#fdfdfe}
.finding.crit{border-left-color:var(--crit)} .finding.high{border-left-color:var(--high)}
.finding.med{border-left-color:var(--med)} .finding.low{border-left-color:var(--low)}
.finding h4{margin:0 0 6px;font-size:15px;color:var(--ink);text-transform:none;letter-spacing:0}
.finding .fid{color:var(--muted);font-size:12px;margin-right:8px}
.impact{background:var(--accent-soft);border-radius:4px;padding:8px 11px;margin:10px 0 0;font-size:13.5px}
.impact b{color:var(--accent)}
details{margin-top:10px}
summary{cursor:pointer;color:var(--accent);font-size:13px;font-weight:600;outline:none}
.ev td{font-size:12.5px}
.ev .ref{white-space:nowrap;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:12px}
pre.snip{margin:0;background:var(--code);border:1px solid var(--line);border-radius:4px;
  padding:6px 8px;font-size:11.8px;white-space:pre-wrap;word-break:break-word;max-height:120px;overflow:auto}
.lineage{display:flex;gap:10px;overflow-x:auto;padding:8px 0 12px;align-items:stretch}
.stage{flex:0 0 210px;border:1px solid var(--line);border-radius:5px;background:#fbfcfd;padding:9px 11px}
.stage h5{margin:0 0 6px;font-size:11.5px;text-transform:uppercase;letter-spacing:.05em;color:var(--accent)}
.stage ul{margin:0;padding-left:15px;font-size:11.8px;color:var(--muted);word-break:break-all}
.arrow{flex:0 0 16px;align-self:center;color:var(--muted);font-size:18px}
.feedhead{font-weight:600;margin-top:14px}
.note{font-size:12.5px;color:var(--muted)}
ul.tight{margin:6px 0;padding-left:20px} ul.tight li{margin:3px 0}
footer{max-width:1500px;margin:0 auto;padding:0 24px 40px;color:var(--muted);font-size:12.5px}
@media print{nav.toc{display:none}section{break-inside:avoid;page-break-inside:avoid}
  body{background:#fff}.layout{display:block}details{display:block}details>summary{display:none}}
"""

JS = """
(function(){
  var buttons = document.querySelectorAll('[data-sev-filter]');
  function apply(sev){
    document.querySelectorAll('.finding').forEach(function(el){
      el.style.display = (sev === 'all' || el.getAttribute('data-severity') === sev) ? '' : 'none';
    });
    buttons.forEach(function(b){
      b.style.outline = (b.getAttribute('data-sev-filter') === sev) ? '2px solid #0b4f6c' : 'none';
    });
  }
  buttons.forEach(function(b){
    b.style.cursor = 'pointer';
    b.addEventListener('click', function(){ apply(b.getAttribute('data-sev-filter')); });
  });
  var expand = document.getElementById('expand-all');
  if (expand) {
    expand.addEventListener('click', function(){
      var open = expand.getAttribute('data-open') !== 'yes';
      document.querySelectorAll('details').forEach(function(d){ d.open = open; });
      expand.setAttribute('data-open', open ? 'yes' : 'no');
      expand.textContent = open ? 'Collapse all evidence' : 'Expand all evidence';
    });
  }
})();
"""


def e(value):
    return html.escape(str(value if value is not None else ""))


def evidence_table(evidence):
    if not evidence:
        return ""
    rows = []
    for item in evidence:
        note = item.get("note", "")
        rows.append(
            "<tr><td class='ref'>%s</td><td>%s<pre class='snip'>%s</pre></td></tr>"
            % (e(item["ref"]), ("<div class='note'>%s</div>" % e(note)) if note else "",
               e(item["snippet"]))
        )
    return ("<details><summary>Evidence (%d)</summary><div class='scroll'>"
            "<table class='ev'><thead><tr><th style='width:230px'>File : line</th>"
            "<th>Snippet</th></tr></thead><tbody>%s</tbody></table></div></details>"
            % (len(evidence), "".join(rows)))


def ref_list(evidence):
    return ", ".join("<span class='mono'>%s</span>" % e(i["ref"]) for i in evidence)


def section(sid, title, lede, body):
    return ("<section id='%s'><h2>%s</h2><p class='lede'>%s</p>%s</section>"
            % (sid, e(title), e(lede), body))


# ---------------------------------------------------------------------------
# Section builders
# ---------------------------------------------------------------------------
def build_summary(d):
    counts = d["severity_counts"]
    cards = "".join(
        "<div class='card'><div class='n'>%s</div><div class='l'>%s</div></div>" % (v, e(k))
        for k, v in [
            ("Findings", len(d["findings"])),
            ("Critical", counts.get("Critical", 0)),
            ("High", counts.get("High", 0)),
            ("Medium", counts.get("Medium", 0)),
            ("Low", counts.get("Low", 0)),
            ("Evidence citations", sum(len(f["evidence"]) for f in d["findings"])),
            ("Feeds inventoried", len(d["feeds"])),
            ("Feeds missing from inventory", len(d["unlisted_feeds"])),
            ("Identifier schemes", len(d["identity_schemes"])),
        ])
    points = "".join("<li>%s</li>" % e(p) for p in d["exec_summary"]["points"])
    cat_rows = "".join(
        "<tr><td><b>%s</b></td><td>%s</td><td>%s</td><td>%s</td></tr>" % (
            e(c["title"]), e(c["summary"]),
            len([f for f in d["findings"] if f["category"] == c["id"]]),
            "".join("<span class='badge %s'>%s</span> " % (
                SEVERITY_CLASS[s],
                len([f for f in d["findings"] if f["category"] == c["id"] and f["severity"] == s]))
                for s in d["severity_order"]
                if any(f["category"] == c["id"] and f["severity"] == s for f in d["findings"])))
        for c in d["categories"])
    body = (
        "<p>%s</p><div class='cards'>%s</div><h3>Key points</h3><ul class='tight'>%s</ul>"
        "<h3>Findings by category</h3><div class='scroll'><table><thead><tr>"
        "<th style='width:220px'>Category</th><th>Assessment</th><th style='width:70px'>Findings</th>"
        "<th style='width:150px'>Severity mix</th></tr></thead><tbody>%s</tbody></table></div>"
        % (e(d["exec_summary"]["headline"]), cards, points, cat_rows))
    return section("exec-summary", "1. Executive summary",
                   "What the estate looks like today and why it cannot produce one agreed number.",
                   body)


def build_estate_overview(d):
    rows = "".join(
        "<tr><td class='mono'>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td>"
        "<td>%s</td><td>%s</td><td>%s</td><td class='ref'>%s</td></tr>" % (
            e(f["feed_id"]), e(f["name"]), e(f["source_system"]), e(f["technology"]),
            e(f["schedule"]), e(f["consumers"]), e(f["owner"]),
            e(f["overlapping_attributes"]), ref_list(f["evidence"]))
        for f in d["feeds"])
    unlisted = "".join(
        "<tr><td class='mono'>%s</td><td>%s</td><td>%s</td><td>%s</td><td class='ref'>%s</td></tr>"
        % (e(u["id"]), e(u["name"]), e(u["tech"]), e(u["why_missing"]), ref_list(u["evidence"]))
        for u in d["unlisted_feeds"])

    infa = "".join(
        "<tr><td class='mono'>%s</td><td class='mono'>%s</td><td>%s</td><td>%s</td>"
        "<td class='ref'>%s</td></tr>" % (
            e(w["name"]), e(w["folder"]), e(w["schedule"]),
            "".join("<span class='pill'>%s (%s)</span>" % (e(t["name"]), e(t["type"]))
                    for t in w["transformations"]),
            e(w["artefact"]))
        for w in d["pipelines"]["informatica"])

    by_engine = {}
    for asset in d["pipelines"]["assets"]:
        by_engine.setdefault(asset["engine"], []).append(asset)
    engine_rows = "".join(
        "<tr><td>%s</td><td>%s</td><td>%s</td><td class='ref'>%s</td></tr>" % (
            e(engine), len(assets), sum(a["line_count"] for a in assets),
            ", ".join(e(a["artefact"]) for a in assets[:4]) + (" …" if len(assets) > 4 else ""))
        for engine, assets in sorted(by_engine.items()))
    asset_rows = "".join(
        "<tr><td class='ref'>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>" % (
            e(a["artefact"]), e(a["engine"]), a["line_count"],
            "; ".join("%s: %s" % (e(k), e(v)) for k, v in a["header"].items()))
        for a in d["pipelines"]["assets"])

    body = (
        "<h3>2.1 Governed feed inventory (parsed from <span class='mono'>docs/feed_inventory.md</span>)</h3>"
        "<div class='scroll'><table><thead><tr><th>Feed</th><th>Name</th><th>Source system</th>"
        "<th>Technology</th><th>Schedule</th><th>Consumers / targets</th><th>Owner</th>"
        "<th>Overlapping attributes</th><th>Evidence</th></tr></thead><tbody>%s</tbody></table></div>"
        "<h3>2.2 Feeds found in code but absent from the inventory</h3>"
        "<p class='note'>Discovered by reading the pipeline assets. Each is a real production "
        "data movement with no feed identifier, no named owner and no DQ coverage.</p>"
        "<div class='scroll'><table><thead><tr><th>Ref</th><th>Feed</th><th>Technology</th>"
        "<th>Why it is missing / why it matters</th><th>Evidence</th></tr></thead>"
        "<tbody>%s</tbody></table></div>"
        "<h3>2.3 Informatica workflows (parsed from the repository XML)</h3>"
        "<div class='scroll'><table><thead><tr><th>Workflow</th><th>Folder</th><th>Schedule</th>"
        "<th>Transformations</th><th>Artefact</th></tr></thead><tbody>%s</tbody></table></div>"
        "<h3>2.4 Estate by engine</h3>"
        "<div class='scroll'><table><thead><tr><th>Engine</th><th>Artefacts</th><th>Lines</th>"
        "<th>Examples</th></tr></thead><tbody>%s</tbody></table></div>"
        "<details><summary>Full artefact inventory (%d files)</summary><div class='scroll'>"
        "<table><thead><tr><th>Artefact</th><th>Engine</th><th>Lines</th><th>Declared header</th>"
        "</tr></thead><tbody>%s</tbody></table></div></details>"
        % (rows, unlisted, infa, engine_rows, len(d["pipelines"]["assets"]), asset_rows))
    return section("estate-overview", "2. Estate overview: feeds and pipelines",
                   "Every governed feed, plus the production data movements the inventory does not know about.",
                   body)


def build_lineage(d):
    blocks = []
    for feed in d["lineage"]:
        stages = []
        for i, layer in enumerate(feed["layers"]):
            if i:
                stages.append("<div class='arrow'>&#8594;</div>")
            stages.append(
                "<div class='stage'><h5>%s</h5><ul>%s</ul></div>" % (
                    e(layer["layer"]),
                    "".join("<li>%s</li>" % e(a) for a in layer["artefacts"])))
        blocks.append("<div class='feedhead'>%s — %s</div><div class='lineage'>%s</div>"
                      % (e(feed["feed_id"]), e(feed["name"]), "".join(stages)))
    body = ("<p class='note'>Each lane is derived by scanning every repository artefact for the "
            "feed's distinctive tokens and grouping the hits by the layer that owns them, so the "
            "map reflects the code rather than the documentation.</p>%s" % "".join(blocks))
    return section("lineage", "3. Lineage map: source to staging to data product",
                   "Where each feed physically travels, derived from artefact references.", body)


def build_identity(d):
    rows = "".join(
        "<tr><td class='mono'><b>%s</b></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td>"
        "<td>%s</td><td>%s</td></tr>" % (
            e(s["scheme"]), e(s["owner_system"]), e(s["grain"]), e(s["format"]),
            e(s["crosswalk"]), s["file_count"], s["occurrence_count"])
        for s in d["identity_schemes"])
    findings = "".join(render_finding(f) for f in d["findings"] if f["category"] == "C1")
    body = (
        "<h3>4.1 The six schemes</h3>"
        "<p class='note'>File and occurrence counts are measured across the working tree at scan time.</p>"
        "<div class='scroll'><table><thead><tr><th>Scheme</th><th>Owning system</th><th>Grain</th>"
        "<th>Physical format</th><th>Crosswalk</th><th>Files</th><th>Occurrences</th>"
        "</tr></thead><tbody>%s</tbody></table></div>"
        "<h3>4.2 How they connect (and do not)</h3>"
        "<div class='lineage'>"
        "<div class='stage'><h5>CUSTOMER_ID</h5><ul><li>APF core banking</li></ul></div>"
        "<div class='arrow'>&#8596;</div>"
        "<div class='stage'><h5>PARTY_ID</h5><ul><li>POLARIS / MDM hub</li>"
        "<li>via PARTY.LEGACY_CUSTOMER_ID, ~55%% populated</li></ul></div>"
        "<div class='arrow'>&#8596;</div>"
        "<div class='stage'><h5>CLIENT_NO</h5><ul><li>LEGACY_PAS mainframe</li>"
        "<li>via REF_DB.XREF_CLIENT_PARTY, manual</li></ul></div>"
        "<div class='arrow'>&#8594;</div>"
        "<div class='stage'><h5>customer_ref</h5><ul><li>SOAP API</li>"
        "<li>NVL(legacy_customer_id, party_id) — two schemes, one field</li></ul></div>"
        "</div>"
        "<div class='lineage'>"
        "<div class='stage'><h5>LIFE_POLICY_ID</h5><ul><li>LIFE400</li>"
        "<li>no person key; name+DOB fuzzy match in a lost-source job</li></ul></div>"
        "<div class='arrow'>&#10007;</div>"
        "<div class='stage'><h5>MKTG_CUST_ID</h5><ul><li>Partner loyalty</li>"
        "<li>never crosswalked to anything</li></ul></div>"
        "</div>"
        "<h3>4.3 Findings</h3>%s" % (rows, findings))
    return section("identity", "4. Identity fragmentation",
                   "Six identifier schemes, two partial crosswalks and a life book with no person key.",
                   body)


def build_matrix(d):
    rows = []
    for row in d["attribute_matrix"]:
        first = True
        for producer in row["producers"]:
            ref = producer["evidence"]["ref"] if producer["evidence"] else ""
            rows.append(
                "<tr>%s<td>%s</td><td class='mono'>%s</td><td>%s</td><td>%s</td>"
                "<td class='ref'>%s</td></tr>" % (
                    ("<td rowspan='%d'><b>%s</b><div class='note'>canonical: %s</div></td>"
                     % (len(row["producers"]), e(row["attribute"]), e(row["canonical"]))) if first else "",
                    e(producer["system"]), e(producer["physical"]), e(producer["format"]),
                    e(producer["derivation"]), e(ref)))
            first = False
    body = ("<p class='note'>Each row group is one business attribute; each line is a system that "
            "independently produces it. Where the derivations differ, the values differ.</p>"
            "<div class='scroll'><table><thead><tr><th style='width:180px'>Attribute</th>"
            "<th>Producing system</th><th>Physical name</th><th>Format</th><th>Derivation</th>"
            "<th>Evidence</th></tr></thead><tbody>%s</tbody></table></div>" % "".join(rows))
    return section("attribute-matrix", "5. Attribute overlap matrix",
                   "The same twelve business attributes, produced independently by up to six systems each.",
                   body)


def divergence_table(d, attribute):
    row = next((r for r in d["attribute_matrix"] if r["attribute"] == attribute), None)
    if not row:
        return ""
    body = "".join(
        "<tr><td>%s</td><td class='mono'>%s</td><td>%s</td><td class='ref'>%s</td></tr>" % (
            e(p["system"]), e(p["physical"]), e(p["derivation"]),
            e(p["evidence"]["ref"] if p["evidence"] else ""))
        for p in row["producers"])
    return ("<div class='scroll'><table><thead><tr><th>Owner / implementation</th><th>Field</th>"
            "<th>Definition in code</th><th>Evidence</th></tr></thead><tbody>%s</tbody>"
            "</table></div>" % body)


def build_definitions(d):
    conflict_rows = "".join(
        "<tr><td rowspan='%d'><b>%s</b></td><td>%s</td><td>%s</td><td class='ref'>%s</td></tr>%s" % (
            len(c["definitions"]), e(c["term"]), e(c["definitions"][0]["community"]),
            e(c["definitions"][0]["definition"]), e(c["definitions"][0]["evidence"]["ref"]),
            "".join("<tr><td>%s</td><td>%s</td><td class='ref'>%s</td></tr>" % (
                e(x["community"]), e(x["definition"]), e(x["evidence"]["ref"]))
                for x in c["definitions"][1:]))
        for c in d["glossary_conflicts"])
    findings = "".join(render_finding(f) for f in d["findings"] if f["category"] == "C3")
    body = (
        "<h3>6.1 Competing definitions parsed from the business glossaries</h3>"
        "<div class='scroll'><table><thead><tr><th style='width:150px'>Term</th><th>Community</th>"
        "<th>Definition as written</th><th>Evidence</th></tr></thead><tbody>%s</tbody></table></div>"
        "<h3>6.2 Earned premium — three concurrent bases</h3>%s"
        "<h3>6.3 Active policy — four concurrent definitions</h3>%s"
        "<h3>6.4 Findings</h3>%s"
        % (conflict_rows, divergence_table(d, "Earned premium"),
           divergence_table(d, "Active policy flag"), findings))
    return section("definitions", "6. Conflicting definitions and metric divergence",
                   "Where the same word means different numbers, and what that costs.", body)


def build_dq(d):
    rows = "".join(
        "<tr><td class='mono'>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td>"
        "<td>%s</td><td>%s</td><td class='ref'>%s</td></tr>" % (
            e(r["rule_id"]), e(r["rule_name"]), e(r["status"]), e(r["owner"]),
            r["registered_count"], r["actual_count"],
            ("<span class='badge sev-high'>+%d</span>" % r["undercount"]) if r["undercount"] else "—",
            e(r["implementations_actual"]), e(r["evidence"]["ref"]))
        for r in d["dq_registry"])
    undercount = sum(r["undercount"] for r in d["dq_registry"])
    findings = "".join(render_finding(f) for f in d["findings"] if f["category"] in ("C2", "C4"))
    body = (
        "<p>Across the registry, <b>%d</b> rule implementations exist that the governance register "
        "does not record. Two of the five postcode implementations were never registered at all, "
        "and the two rules with the widest blast radius (century derivation and policy status "
        "domain) have <i>no</i> registered implementation.</p>"
        "<div class='scroll'><table><thead><tr><th>Rule</th><th>Name</th><th>Status</th><th>Owner</th>"
        "<th>Registered</th><th>Actual</th><th>Gap</th><th>Implementations found in code</th>"
        "<th>Evidence</th></tr></thead><tbody>%s</tbody></table></div>"
        "<h3>7.1 Findings — rule drift and format chaos</h3>%s" % (undercount, rows, findings))
    return section("dq-drift", "7. DQ and transformation rule overlap, duplication and drift",
                   "Registered rules versus what the code actually does, with file-level evidence.",
                   body)


def build_operations(d):
    rows = "".join(
        "<tr><td>%s</td><td class='mono'>%s</td><td>%s</td><td>%s</td><td class='mono'>%s</td>"
        "<td>%s</td><td class='ref'>%s</td></tr>" % (
            e(s["scheduler"]), e(s["job"]), e(s["time"]), e(s["description"]),
            e(s["command"]), e("; ".join(s["dependencies"]) or "—"),
            ref_list(s["evidence"]))
        for s in d["schedules"])
    findings = "".join(render_finding(f) for f in d["findings"]
                       if f["category"] in ("C5", "C6", "C7"))
    body = (
        "<h3>8.1 Scheduling inventory (parsed from Control-M, cron, AS/400 and DataStage)</h3>"
        "<div class='scroll'><table><thead><tr><th>Scheduler</th><th>Job</th><th>Time</th>"
        "<th>Description</th><th>Command</th><th>Dependencies</th><th>Evidence</th>"
        "</tr></thead><tbody>%s</tbody></table></div>"
        "<h3>8.2 Findings — clone drift, scheduling, consumption debt and platform risk</h3>%s"
        % (rows, findings))
    return section("operations", "8. Pipeline clone drift, scheduling, consumption and platform risk",
                   "Four schedulers, an un-reconverged clone estate, a frozen SOAP contract and a lost job source.",
                   body)


def build_target_model(d):
    blocks = []
    for domain in d["target_domains"]:
        blocks.append(
            "<h3>%s</h3><p>%s</p>"
            "<table><tbody>"
            "<tr><th style='width:170px'>Key</th><td class='mono'>%s</td></tr>"
            "<tr><th>Core attributes</th><td>%s</td></tr>"
            "<tr><th>Sources consolidated</th><td>%s</td></tr>"
            "<tr><th>Design note</th><td>%s</td></tr>"
            "</tbody></table>" % (
                e(domain["domain"]), e(domain["purpose"]), e(domain["key"]),
                "".join("<span class='pill'>%s</span>" % e(a) for a in domain["core_attributes"]),
                "".join("<span class='pill'>%s</span>" % e(s) for s in domain["sources"]),
                e(domain["notes"])))
    body = ("<p>One canonical model, six domains. Every legacy identifier is preserved as a "
            "crosswalk row rather than promoted to a key, and every competing definition becomes "
            "a named, tested view rather than a silently different column.</p>%s"
            % "".join(blocks))
    return section("target-model", "9. Recommended unified data model",
                   "Party, Policy, Claim, Premium & Billing, Reinsurance and Life.", body)


def build_recommendation(d):
    rec = d["platform_recommendation"]
    why = "".join("<li>%s</li>" % e(w) for w in rec["why"])
    alts = "".join(
        "<tr><td><b>%s</b></td><td><span class='badge %s'>%s</span></td><td>%s</td></tr>" % (
            e(a["option"]),
            "sev-low" if a["verdict"] == "Viable" else "sev-medium",
            e(a["verdict"]), e(a["reasoning"]))
        for a in rec["alternatives"])
    services = "".join(
        "<tr><td><b>%s</b></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>" % (
            e(s["service"]), e(s["owns"]), e(s["contract"]), e(s["dq"]), e(s["owner"]))
        for s in rec["services"])
    roadmap = "".join(
        "<tr><td><b>%s</b></td><td><ul class='tight'>%s</ul></td><td>%s</td></tr>" % (
            e(p["phase"]), "".join("<li>%s</li>" % e(a) for a in p["actions"]), e(p["risks"]))
        for p in rec["roadmap"])
    body = (
        "<h3>10.1 Target platform</h3><p><b>%s</b></p><ul class='tight'>%s</ul>"
        "<h3>10.2 Alternatives considered</h3><div class='scroll'><table><thead><tr>"
        "<th style='width:250px'>Option</th><th style='width:90px'>Verdict</th><th>Reasoning</th>"
        "</tr></thead><tbody>%s</tbody></table></div>"
        "<h3>10.3 Data domain services: ownership, contracts and DQ placement</h3>"
        "<div class='scroll'><table><thead><tr><th>Service</th><th>Owns</th><th>Contract</th>"
        "<th>DQ tests (dbt)</th><th>Accountable owner</th></tr></thead><tbody>%s</tbody></table></div>"
        "<h3>10.4 Migration phases and risks</h3><div class='scroll'><table><thead><tr>"
        "<th style='width:200px'>Phase</th><th>Actions</th><th style='width:280px'>Principal risk</th>"
        "</tr></thead><tbody>%s</tbody></table></div>"
        % (e(rec["target"]), why, alts, services, roadmap))
    return section("recommendation", "10. Recommended data domain services and target architecture",
                   "Snowflake + dbt with domain-aligned products, contracts and DQ at the boundary.",
                   body)


def build_method(d):
    meta = d["meta"]
    body = (
        "<p>This report is generated, not written by hand. "
        "<span class='mono'>tools/assessment/estate_scan.py</span> parses the estate's own "
        "artefacts and resolves every analyst claim in "
        "<span class='mono'>tools/assessment/findings_catalogue.py</span> against the working "
        "tree; a claim whose evidence no longer matches fails the scan. "
        "<span class='mono'>tools/assessment/render_report.py</span> renders this single "
        "self-contained HTML file — all CSS and JavaScript are inlined and no external resource "
        "is fetched.</p>"
        "<h3>Reproduce</h3>"
        "<pre class='snip'>python3 tools/assessment/run_assessment.py</pre>"
        "<h3>Machine-readable outputs</h3><ul class='tight'>"
        "<li><span class='mono'>docs/assessment/data/assessment_findings.json</span> — full dataset</li>"
        "<li><span class='mono'>docs/assessment/data/findings.csv</span></li>"
        "<li><span class='mono'>docs/assessment/data/feed_inventory.csv</span></li>"
        "<li><span class='mono'>docs/assessment/data/attribute_overlap_matrix.csv</span></li>"
        "<li><span class='mono'>docs/assessment/data/dq_rule_drift.csv</span></li>"
        "<li><span class='mono'>docs/assessment/data/schedule_inventory.csv</span></li></ul>"
        "<h3>Scan provenance</h3><div class='scroll'><table><tbody>"
        "<tr><th style='width:220px'>Ticket</th><td>%s</td></tr>"
        "<tr><th>Generated (UTC)</th><td>%s</td></tr>"
        "<tr><th>Repository commit</th><td class='mono'>%s</td></tr>"
        "<tr><th>Files scanned</th><td>%s</td></tr>"
        "<tr><th>Evidence citations resolved</th><td>%s</td></tr>"
        "<tr><th>Unresolved probes</th><td>%s</td></tr>"
        "</tbody></table></div>"
        "<p class='note'>Scope note: this assessment is analysis only. No pipeline asset was "
        "modified; the only files added are under <span class='mono'>tools/assessment/</span> and "
        "<span class='mono'>docs/assessment/</span>.</p>"
        % (e(meta["ticket"]), e(meta["generated_at_utc"]), e(meta["git_commit"]),
           meta["scanned_file_count"], sum(len(f["evidence"]) for f in d["findings"]),
           len(d["unresolved_probes"])))
    return section("method", "11. Method, reproducibility and scope",
                   "How this report was produced and how to regenerate it.", body)


def render_finding(f):
    cls = {"Critical": "crit", "High": "high", "Medium": "med", "Low": "low"}[f["severity"]]
    return (
        "<div class='finding %s' data-severity='%s'>"
        "<h4><span class='fid mono'>%s</span>%s "
        "<span class='badge %s'>%s</span></h4>"
        "<p>%s</p><div class='impact'><b>Business impact:</b> %s</div>%s</div>"
        % (cls, e(f["severity"]), e(f["id"]), e(f["title"]),
           SEVERITY_CLASS[f["severity"]], e(f["severity"]),
           e(f["summary"]), e(f["impact"]), evidence_table(f["evidence"])))


TOC = [
    ("exec-summary", "1. Executive summary"),
    ("estate-overview", "2. Estate overview"),
    ("lineage", "3. Lineage map"),
    ("identity", "4. Identity fragmentation"),
    ("attribute-matrix", "5. Attribute overlap matrix"),
    ("definitions", "6. Conflicting definitions"),
    ("dq-drift", "7. DQ rule overlap & drift"),
    ("operations", "8. Pipelines, scheduling & platform risk"),
    ("target-model", "9. Unified data model"),
    ("recommendation", "10. Domain services & target architecture"),
    ("method", "11. Method & reproducibility"),
]


def render(d):
    meta = d["meta"]
    toc = "".join("<a href='#%s'>%s</a>" % (sid, e(title)) for sid, title in TOC)
    filters = "".join(
        "<span class='badge %s' data-sev-filter='%s'>%s</span> " % (SEVERITY_CLASS[s], s, s)
        for s in d["severity_order"])
    controls = (
        "<section id='controls'><h2>Report controls</h2>"
        "<p class='lede'>Filter findings by severity, or expand every evidence table at once.</p>"
        "<p>%s<span class='pill' data-sev-filter='all'>Show all</span>"
        "&nbsp;&nbsp;<span class='pill' id='expand-all' data-open='no' "
        "style='cursor:pointer'>Expand all evidence</span></p></section>")% filters
    sections = "".join([
        build_summary(d), controls, build_estate_overview(d), build_lineage(d),
        build_identity(d), build_matrix(d), build_definitions(d), build_dq(d),
        build_operations(d), build_target_model(d), build_recommendation(d), build_method(d),
    ])
    return (
        "<!DOCTYPE html>\n<html lang='en'>\n<head>\n<meta charset='utf-8'>\n"
        "<meta name='viewport' content='width=device-width, initial-scale=1'>\n"
        "<title>Albion Data Estate Assessment — ADEM-1</title>\n"
        "<style>%s</style>\n</head>\n<body>\n"
        "<header class='masthead'><h1>Albion General Insurance Group — Legacy Data Estate Assessment</h1>"
        "<div class='sub'>Feed and pipeline inventory, attribute and DQ overlap, and a unified data "
        "model plus Snowflake/dbt domain-services recommendation</div>"
        "<div class='meta-strip'><span>Ticket %s</span><span>Generated %s</span>"
        "<span>Commit %s</span><span>%s files scanned</span><span>%s findings</span>"
        "<span>%s evidence citations</span></div></header>\n"
        "<div class='layout'><nav class='toc'><h2>Contents</h2>%s</nav><main>%s</main></div>\n"
        "<footer>Generated by <span class='mono'>tools/assessment/run_assessment.py</span> from the "
        "repository working tree. Self-contained: no external CSS, fonts, images or scripts.</footer>\n"
        "<script>%s</script>\n</body>\n</html>\n"
        % (CSS, e(meta["ticket"]), e(meta["generated_at_utc"]), e(meta["git_commit"]),
           meta["scanned_file_count"], len(d["findings"]),
           sum(len(f["evidence"]) for f in d["findings"]), toc, sections, JS))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    repo_root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    parser.add_argument("--data", default=os.path.join(repo_root, "docs", "assessment", "data",
                                                       "assessment_findings.json"))
    parser.add_argument("--out", default=os.path.join(repo_root, "docs", "assessment",
                                                      "albion_data_estate_assessment.html"))
    args = parser.parse_args(argv)

    with open(args.data, "r", encoding="utf-8") as fh:
        dataset = json.load(fh)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(render(dataset))
    print("Wrote %s (%.1f KB)" % (args.out, os.path.getsize(args.out) / 1024.0))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

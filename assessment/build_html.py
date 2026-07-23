#!/usr/bin/env python3
"""Render the assessment markdown deliverables into a single self-contained HTML report.

Usage: python3 assessment/build_html.py
Requires: markdown (pip install markdown)
"""
from __future__ import annotations

import pathlib

import markdown

HERE = pathlib.Path(__file__).resolve().parent

SECTIONS = [
    ("summary", "Summary", "README.md"),
    ("d1", "1 · Feed / Pipeline Inventory", "01_feed_inventory.md"),
    ("d2", "2 · Attribute-Overlap Matrix", "02_attribute_overlap_matrix.md"),
    ("d3", "3 · Glossary Reconciliation", "03_glossary_reconciliation.md"),
    ("d4", "4 · DQ Registry Diff", "04_dq_registry_diff.md"),
]

CSS = """
:root{--bg:#0f1420;--panel:#161d2e;--ink:#e7ecf5;--mut:#9aa7bd;--acc:#4da3ff;--brd:#26324a;--warn:#ffb454}
*{box-sizing:border-box}
body{margin:0;font:15px/1.6 -apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background:var(--bg);color:var(--ink)}
header{padding:28px 32px;border-bottom:1px solid var(--brd);background:linear-gradient(180deg,#182136,#0f1420)}
header h1{margin:0 0 4px;font-size:22px}
header p{margin:0;color:var(--mut);font-size:13px}
.wrap{display:flex;gap:0;align-items:flex-start}
nav{position:sticky;top:0;flex:0 0 240px;height:100vh;overflow:auto;padding:22px 16px;border-right:1px solid var(--brd);background:var(--panel)}
nav a{display:block;padding:8px 12px;color:var(--mut);text-decoration:none;border-radius:8px;font-size:14px}
nav a:hover{background:#1e2740;color:var(--ink)}
main{flex:1;min-width:0;padding:28px 40px;max-width:1200px}
section{margin-bottom:56px;scroll-margin-top:16px}
h1,h2,h3{line-height:1.25}
h2{font-size:20px;border-bottom:1px solid var(--brd);padding-bottom:6px;margin-top:0}
h3{font-size:16px;color:var(--acc)}
a{color:var(--acc)}
code{background:#0c1220;border:1px solid var(--brd);border-radius:5px;padding:1px 5px;font:13px/1.4 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;color:#cfe0ff}
table{border-collapse:collapse;width:100%;margin:14px 0;font-size:13.5px;display:block;overflow-x:auto}
th,td{border:1px solid var(--brd);padding:7px 10px;text-align:left;vertical-align:top}
th{background:#1c2740;color:var(--ink);position:sticky;top:0}
tr:nth-child(even) td{background:#131a2b}
blockquote{border-left:3px solid var(--acc);margin:12px 0;padding:2px 14px;color:var(--mut)}
.badge{display:inline-block;background:#1c2740;border:1px solid var(--brd);color:var(--warn);border-radius:999px;padding:2px 10px;font-size:12px;margin-left:8px}
footer{padding:22px 40px;color:var(--mut);border-top:1px solid var(--brd);font-size:12px}
"""


def main() -> None:
    md = markdown.Markdown(extensions=["tables", "fenced_code", "toc", "sane_lists"])
    nav = "\n".join(
        f'<a href="#{sid}">{title}</a>' for sid, title, _ in SECTIONS
    )
    body_parts = []
    for sid, title, fname in SECTIONS:
        md.reset()
        html = md.convert((HERE / fname).read_text(encoding="utf-8"))
        body_parts.append(
            f'<section id="{sid}"><h2>{title}</h2>{html}</section>'
        )
    doc = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Albion General — Data Estate Assessment</title>
<style>{CSS}</style>
</head>
<body>
<header>
  <h1>Albion General Insurance Group — Legacy Data Estate Assessment
    <span class="badge">Assess phase</span></h1>
  <p>Analysis &amp; documentation only. Every finding cites exact file paths and line numbers.</p>
</header>
<div class="wrap">
  <nav>{nav}</nav>
  <main>{''.join(body_parts)}</main>
</div>
<footer>Generated from the markdown deliverables in <code>assessment/</code> via
<code>build_html.py</code>. No legacy source files were modified.</footer>
</body>
</html>
"""
    (HERE / "assessment.html").write_text(doc, encoding="utf-8")
    print("wrote", HERE / "assessment.html")


if __name__ == "__main__":
    main()

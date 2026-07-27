#!/usr/bin/env python3
"""Run the full Albion data-estate assessment: scan the repo, then render the report.

Equivalent to running ``estate_scan.py`` followed by ``render_report.py`` with
default paths. Exits non-zero if any evidence probe fails to resolve against
the working tree.

Usage::

    python3 tools/assessment/run_assessment.py
"""

from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import estate_scan  # noqa: E402
import render_report  # noqa: E402

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", default=REPO_ROOT)
    parser.add_argument("--allow-unresolved", action="store_true")
    args = parser.parse_args(argv)

    repo_root = os.path.abspath(args.repo_root)
    data_dir = os.path.join(repo_root, "docs", "assessment", "data")
    report = os.path.join(repo_root, "docs", "assessment", "albion_data_estate_assessment.html")

    scan_argv = ["--repo-root", repo_root, "--out-dir", data_dir]
    if args.allow_unresolved:
        scan_argv.append("--allow-unresolved")
    rc = estate_scan.main(scan_argv)
    if rc != 0:
        return rc
    return render_report.main(["--data", os.path.join(data_dir, "assessment_findings.json"),
                               "--out", report])


if __name__ == "__main__":
    raise SystemExit(main())

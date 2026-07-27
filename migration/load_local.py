#!/usr/bin/env python3
"""Land all checked-in feeds into deterministic canonical CSVs for dbt."""

from __future__ import annotations

import csv
import json
import re
from collections import Counter
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
OUT = ROOT / "migration" / "output"
AS_OF = date(2026, 1, 15)
POLICY_STATUSES = {"IF": "ACTIVE", "RN": "ACTIVE", "LP": "LAPSED", "CN": "CANCELLED", "EX": "EXPIRED"}
LIFE_STATUSES = {"AC": "ACTIVE", "GR": "ACTIVE", "RS": "ACTIVE", "LA": "LAPSED", "PE": "LAPSED", "CL": "CANCELLED", "TE": "EXPIRED"}
CLAIM_STATUSES = {"O": "OPEN", "S": "CLOSED", "R": "REOPENED", "D": "DECLINED"}
CANONICAL_CLAIM_STATUSES = set(CLAIM_STATUSES.values())


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


def dashed_policy(raw: str) -> str:
    value = raw.strip()
    if value.startswith("AL/"):
        compact = value.replace("-", "")
        return f"ALB-{compact[3:6]}-{compact[6:]}"
    value = value.replace("-", "")
    if value.startswith("ALB") and len(value) >= 7:
        return f"{value[:3]}-{value[3:6]}-{value[6:]}"
    return value


def pivot_year(two_digit: str) -> int:
    yy = int(two_digit)
    return 2000 + yy if yy <= 39 else 1900 + yy


def parse_julian(raw: str) -> date:
    return date(pivot_year(raw[:2]), 1, 1) + timedelta(days=int(raw[2:]) - 1)


def parse_yymmdd(raw: str) -> date:
    return date(pivot_year(raw[:2]), int(raw[2:4]), int(raw[4:6]))


def parse_loss_date(raw: str) -> date:
    value = raw.strip()
    if "/" in value:
        day, month, year = value.split("/")
        return date(int(year), int(month), int(day))
    return date.fromisoformat(value)


def parse_optional_date(raw: str) -> str:
    value = (raw or "").strip()
    return parse_loss_date(value).isoformat() if value else ""


def money(raw: str) -> str:
    return f"{Decimal(re.sub(r'[£,\s"]', '', raw or '')):.2f}"


def postcode(raw: str | None) -> tuple[str, str]:
    value = (raw or "").strip()
    if not value:
        return "", "MISSING"
    if " " not in value and len(value) >= 5:
        value = value[:-3] + " " + value[-3:]
    value = value.upper()
    status = "VALID" if re.fullmatch(r"[A-Z]{1,2}[0-9][A-Z0-9]? [0-9][A-Z]{2}", value) else "INVALID"
    return value, status


def fraud(raw: str | None) -> str:
    return {"Y": "Y", "S": "SUSPECTED", "N": "N", "": "N"}.get((raw or "").strip().upper(), "N")


def write_csv(path: Path, fields: list[str], values: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(values)


def run() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    rejects: list[dict] = []
    reconciliation: list[dict] = []

    def report(feed: str, source: int, loaded: int, rejected: list[dict], warnings: list[dict]) -> None:
        assert source == loaded + len(rejected)
        reconciliation.append(
            {
                "feed": feed,
                "source_rows": source,
                "loaded_rows": loaded,
                "rejected_rows": len(rejected),
                "warning_rows": len(warnings),
                "warning_reasons": json.dumps(dict(Counter(w["reason"] for w in warnings)), sort_keys=True),
                "reject_reasons": json.dumps(dict(Counter(r["reason"] for r in rejected)), sort_keys=True),
            }
        )

    party_rows = read_csv(DATA / "01_source_tables" / "parties.csv")
    parties = {r["PARTY_ID"]: r for r in party_rows}
    party_by_client = {
        f"{int(r['LEGACY_CUSTOMER_ID']):010d}": r["PARTY_ID"]
        for r in party_rows
        if r["LEGACY_CUSTOMER_ID"].strip()
    }
    canonical_parties = []
    canonical_xref = []
    for party in party_rows:
        canonical_parties.append(
            {
                "party_id": party["PARTY_ID"],
                "party_type": party["PARTY_TYPE"],
                "first_name": party["FIRST_NAME"],
                "last_name": party["LAST_NAME"],
                "birth_dt": party["BIRTH_DT"],
                "email_addr": party["EMAIL_ADDR"],
                "phone": party["PHONE"],
                "addr_line1": party["ADDR_LINE1"],
                "city": party["CITY"],
                "postcode": party["POSTCODE"],
                "legacy_customer_id": party["LEGACY_CUSTOMER_ID"],
                "mdm_golden_flag": party["MDM_GOLDEN_FLAG"],
                "create_dt": party["CREATE_DT"],
            }
        )
        if party["LEGACY_CUSTOMER_ID"].strip():
            canonical_xref.append(
                {
                    "client_no": f"{int(party['LEGACY_CUSTOMER_ID']):010d}",
                    "party_id": party["PARTY_ID"],
                    "match_method": "LEGACY_CUSTOMER_ID",
                    "match_confidence": "1.00",
                    "loaded_by": "local_loader",
                    "load_dt": AS_OF.isoformat(),
                }
            )

    source_policy_rows = read_csv(DATA / "01_source_tables" / "policies.csv")
    source_policies = {r["POLICY_NO"]: r for r in source_policy_rows}
    policy_rejects = []
    canonical_policies: dict[str, dict] = {}
    for row_no, row in enumerate(source_policy_rows, 2):
        if row["POLICY_NO"] in canonical_policies:
            item = {"feed": "data/01_source_tables/policies.csv", "line_number": row_no, "reason": f"DUPLICATE_POLICY_NO:{row['POLICY_NO']}"}
            policy_rejects.append(item)
            rejects.append(item)
            continue
        status = POLICY_STATUSES.get(row["POLICY_STATUS"])
        if status is None:
            item = {"feed": "data/01_source_tables/policies.csv", "line_number": row_no, "reason": f"DQR-030_UNKNOWN_POLICY_STATUS:{row['POLICY_STATUS']}"}
            policy_rejects.append(item)
            rejects.append(item)
            continue
        party = parties.get(row["PARTY_ID"], {})
        pc, pc_status = postcode(party.get("POSTCODE"))
        canonical_policies[row["POLICY_NO"]] = {
            "policy_id": row["POLICY_NO"],
            "legacy_policy_no": row["POLICY_NO"].replace("-", ""),
            "party_id": row["PARTY_ID"] or "",
            "product_code": row["PRODUCT_CD"],
            "inception_date": row["INCEPTION_DT"],
            "expiry_date": row["EXPIRY_DT"],
            "status": status,
            "annual_premium_gbp": f"{Decimal(row['ANNUAL_PREMIUM_GBP']):.2f}",
            "earned_premium_gbp": "",
            "postcode": pc,
            "postcode_dq_status": pc_status,
            "broker_id": row["BROKER_ID"] or "",
            "source_system": "PLCYMSTR",
            "modal_premium": "",
            "pay_frequency": "",
            "date_derivation": "SOURCE_ISO",
        }
    report("data/01_source_tables/policies.csv", len(source_policy_rows), len(canonical_policies), policy_rejects, [])

    plcymstr_lines = (DATA / "inbound_feeds" / "PLCYMSTR_D260115.dat").read_text(encoding="cp1252").splitlines()
    plcymstr_rejects: list[dict] = []
    plcymstr_warnings: list[dict] = []
    plcymstr_parsed = []
    seen_plcymstr_policies: set[str] = set()
    for line_no, raw in enumerate(plcymstr_lines, 1):
        if len(raw) < 78:
            item = {"feed": "PLCYMSTR_D260115.dat", "line_number": line_no, "reason": "SHORT_RECORD"}
            plcymstr_rejects.append(item)
            rejects.append(item)
            continue
        legacy = raw[0:18].strip()
        policy_id = dashed_policy(legacy)
        if policy_id in seen_plcymstr_policies:
            item = {"feed": "PLCYMSTR_D260115.dat", "line_number": line_no, "reason": f"DUPLICATE_POLICY_NO:{legacy}"}
            plcymstr_rejects.append(item)
            rejects.append(item)
            continue
        seen_plcymstr_policies.add(policy_id)
        status = POLICY_STATUSES.get(raw[48:50].strip())
        if policy_id not in canonical_policies:
            item = {"feed": "PLCYMSTR_D260115.dat", "line_number": line_no, "reason": "POLICY_NOT_IN_SOURCE_TABLE"}
            plcymstr_rejects.append(item)
            rejects.append(item)
            continue
        if status is None:
            item = {"feed": "PLCYMSTR_D260115.dat", "line_number": line_no, "reason": f"DQR-030_UNKNOWN_POLICY_STATUS:{raw[48:50].strip()}"}
            plcymstr_rejects.append(item)
            rejects.append(item)
            continue
        client_no = raw[18:28].strip()
        party_id = party_by_client.get(f"{int(client_no):010d}") if client_no.isdigit() else None
        source_party_id = canonical_policies[policy_id]["party_id"]
        if not party_id:
            warning_reason = (
                "DQR-041_UNMATCHED_CLIENT_NO_FALLBACK_SOURCE_PARTY"
                if source_party_id
                else "DQR-041_UNMATCHED_CLIENT_NO_NO_PARTY"
            )
            plcymstr_warnings.append({"feed": "PLCYMSTR_D260115.dat", "line_number": line_no, "reason": warning_reason})
        resolved_party_id = party_id or source_party_id
        pc, pc_status = postcode(raw[50:58])
        record = canonical_policies[policy_id]
        record.update(
            {
                "legacy_policy_no": legacy,
                "party_id": resolved_party_id,
                "product_code": raw[28:32].strip(),
                "inception_date": parse_julian(raw[32:37]).isoformat(),
                "annual_premium_gbp": f"{Decimal(raw[37:48]) / 100:.2f}",
                "status": status,
                "postcode": pc,
                "postcode_dq_status": pc_status,
                "date_derivation": "PIVOT_40_JULIAN",
            }
        )
        plcymstr_parsed.append(
            {
                "policy_id": policy_id,
                "legacy_policy_no": legacy,
                "client_no": client_no,
                "party_id": resolved_party_id,
                "product_code": raw[28:32].strip(),
                "inception_date": parse_julian(raw[32:37]).isoformat(),
                "annual_premium_gbp": f"{Decimal(raw[37:48]) / 100:.2f}",
                "source_status": raw[48:50].strip(),
                "postcode": pc,
                "postcode_dq_status": pc_status,
                "source_system": "PLCYMSTR",
                "date_derivation": "PIVOT_40_JULIAN",
            }
        )
    report("PLCYMSTR_D260115.dat", len(plcymstr_lines), len(plcymstr_lines) - len(plcymstr_rejects), plcymstr_rejects, plcymstr_warnings)

    life_lines = (DATA / "inbound_feeds" / "POLMSTEX_D260115.dat").read_text(encoding="cp1252").splitlines()
    life_rejects: list[dict] = []
    life_records = []
    for line_no, raw in enumerate(life_lines, 1):
        if len(raw) < 116:
            item = {"feed": "POLMSTEX_D260115.dat", "line_number": line_no, "reason": "SHORT_RECORD"}
            life_rejects.append(item)
            rejects.append(item)
            continue
        life_code = raw[35:37].strip()
        status = LIFE_STATUSES.get(life_code)
        if status is None:
            item = {"feed": "POLMSTEX_D260115.dat", "line_number": line_no, "reason": f"DQR-030_UNKNOWN_LIFE_STATUS:{life_code}"}
            life_rejects.append(item)
            rejects.append(item)
            continue
        modal = Decimal(raw[99:112]) / 100
        frequency = int(raw[114:116])
        annual = modal * frequency
        life_records.append(
            {
                "policy_id": raw[0:12].strip(),
                "legacy_policy_no": raw[0:12].strip(),
                "party_id": "",
                "product_code": raw[30:35].strip(),
                "inception_date": parse_yymmdd(raw[24:30]).isoformat(),
                "expiry_date": "",
                "status": status,
                "annual_premium_gbp": f"{annual:.2f}",
                "earned_premium_gbp": "",
                "postcode": "",
                "postcode_dq_status": "MISSING",
                "broker_id": "",
                "source_system": "LIFE400",
                "modal_premium": f"{modal:.2f}",
                "pay_frequency": f"{frequency:02d}",
                "date_derivation": "PIVOT_40_YYMMDD",
            }
        )
    report("POLMSTEX_D260115.dat", len(life_lines), len(life_records), life_rejects, [])

    canonical_policy_records = list(canonical_policies.values()) + life_records
    write_csv(OUT / "policies.csv", list(canonical_policy_records[0]), canonical_policy_records)
    write_csv(OUT / "parties.csv", list(canonical_parties[0]), canonical_parties)
    write_csv(OUT / "xref_client_party.csv", list(canonical_xref[0]), canonical_xref)
    write_csv(OUT / "plcymstr_parsed.csv", list(plcymstr_parsed[0]), plcymstr_parsed)
    write_csv(OUT / "life_policy.csv", list(life_records[0]), life_records)

    claims: list[dict] = []
    claim_source_rows = read_csv(DATA / "01_source_tables" / "claims.csv")
    claim_rejects: list[dict] = []
    seen_claim_ids: set[str] = set()
    for row_no, row in enumerate(claim_source_rows, 2):
        if row["CLAIM_NO"] in seen_claim_ids:
            item = {"feed": "data/01_source_tables/claims.csv", "line_number": row_no, "reason": f"DUPLICATE_CLAIM_NO:{row['CLAIM_NO']}"}
            claim_rejects.append(item)
            rejects.append(item)
            continue
        status = row["CLAIM_STATUS"] if row["CLAIM_STATUS"] in CANONICAL_CLAIM_STATUSES else CLAIM_STATUSES.get(row["CLAIM_STATUS"])
        if status is None:
            item = {"feed": "data/01_source_tables/claims.csv", "line_number": row_no, "reason": f"UNKNOWN_CLAIM_STATUS:{row['CLAIM_STATUS']}"}
            claim_rejects.append(item)
            rejects.append(item)
            continue
        try:
            loss_date = parse_loss_date(row["LOSS_DT"]).isoformat()
        except (TypeError, ValueError):
            item = {"feed": "data/01_source_tables/claims.csv", "line_number": row_no, "reason": f"INVALID_LOSS_DT:{row['LOSS_DT']}"}
            claim_rejects.append(item)
            rejects.append(item)
            continue
        try:
            notified_date = parse_optional_date(row["NOTIFICATION_DT"])
        except (TypeError, ValueError):
            item = {"feed": "data/01_source_tables/claims.csv", "line_number": row_no, "reason": f"INVALID_NOTIFICATION_DT:{row['NOTIFICATION_DT']}"}
            claim_rejects.append(item)
            rejects.append(item)
            continue
        seen_claim_ids.add(row["CLAIM_NO"])
        claims.append(
            {
                "claim_id": row["CLAIM_NO"],
                "policy_id": row["POLICY_NO"],
                "loss_date": loss_date,
                "notified_date": notified_date,
                "status": status,
                "incurred_gbp": f"{Decimal(row['INCURRED_AMT']):.2f}",
                "paid_gbp": f"{Decimal(row['PAID_AMT']):.2f}",
                "fraud_flag": fraud(row["FRAUD_FLAG"]),
                "source_system": "GUIDEWIRE" if row["SOURCE_SYSTEM"] == "GUIDEWIRE_CC" else "PLCYMSTR",
            }
        )
    report("data/01_source_tables/claims.csv", len(claim_source_rows), len(claims), claim_rejects, [])

    bdx_rows = read_csv(DATA / "inbound_feeds" / "CLAIMS_BDX_BRK0007_202606.csv")
    bdx_rejects: list[dict] = []
    for row_no, row in enumerate(bdx_rows, 2):
        claim_id = row["Bordereau Ref"]
        policy_id = dashed_policy(row["Policy Reference"])
        status = CLAIM_STATUSES.get(row["Status"])
        if status is None:
            item = {"feed": "CLAIMS_BDX_BRK0007_202606.csv", "line_number": row_no, "reason": f"UNKNOWN_CLAIM_STATUS:{row['Status']}"}
            bdx_rejects.append(item)
            rejects.append(item)
            continue
        if claim_id in seen_claim_ids:
            item = {"feed": "CLAIMS_BDX_BRK0007_202606.csv", "line_number": row_no, "reason": f"DUPLICATE_CLAIM_NO:{claim_id}"}
            bdx_rejects.append(item)
            rejects.append(item)
            continue
        if policy_id not in canonical_policies:
            item = {"feed": "CLAIMS_BDX_BRK0007_202606.csv", "line_number": row_no, "reason": f"POLICY_NOT_IN_POLICY_MASTER:{policy_id}"}
            bdx_rejects.append(item)
            rejects.append(item)
            continue
        try:
            loss_date = parse_loss_date(row["Date of Loss"]).isoformat()
        except (TypeError, ValueError):
            item = {"feed": "CLAIMS_BDX_BRK0007_202606.csv", "line_number": row_no, "reason": f"INVALID_LOSS_DT:{row['Date of Loss']}"}
            bdx_rejects.append(item)
            rejects.append(item)
            continue
        seen_claim_ids.add(claim_id)
        claims.append(
            {
                "claim_id": claim_id,
                "policy_id": policy_id,
                "loss_date": loss_date,
                "notified_date": "",
                "status": status,
                "incurred_gbp": money(row["Est. Incurred (GBP)"]),
                "paid_gbp": money(row["Paid to Date"]),
                "fraud_flag": "N",
                "source_system": "PLCYMSTR",
            }
        )
    report("CLAIMS_BDX_BRK0007_202606.csv", len(bdx_rows), len(bdx_rows) - len(bdx_rejects), bdx_rejects, [])
    write_csv(OUT / "claims.csv", list(claims[0]), claims)
    write_csv(OUT / "rejects.csv", ["feed", "line_number", "reason"], rejects)
    write_csv(OUT / "reconciliation.csv", list(reconciliation[0]), reconciliation)


if __name__ == "__main__":
    run()

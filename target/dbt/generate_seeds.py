#!/usr/bin/env python3
"""Generate dbt seed CSVs for the Albion target project from the legacy sample
data under data/01_source_tables/ and data/inbound_feeds/.

Run from the repo root:  python target/dbt/generate_seeds.py

This is a build helper (not part of the dbt run). It:
  * copies the relevant operational CSVs into target/dbt/seeds/ with lowercase
    headers so Snowflake identifiers are predictable;
  * parses the fixed-width mainframe PLCYMSTR flat feed (copybook PLCYMSTR.cpy)
    into raw_plcymstr.csv;
  * parses the fixed-width LIFE400 POLMSTEX flat feed (feed spec) into
    raw_life_policy.csv (dates kept as raw YYMMDD integers, as landed);
  * synthesises a REF_DB.XREF_CLIENT_PARTY crosswalk seed from the party file.
"""
import csv
import os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, "data", "01_source_tables")
FEEDS = os.path.join(REPO, "data", "inbound_feeds")
SEEDS = os.path.join(REPO, "target", "dbt", "seeds")
os.makedirs(SEEDS, exist_ok=True)


def copy_lower(src_name, dst_name):
    with open(os.path.join(SRC, src_name), newline="") as fh:
        rows = list(csv.reader(fh))
    rows[0] = [c.strip().lower() for c in rows[0]]
    with open(os.path.join(SEEDS, dst_name), "w", newline="") as fh:
        csv.writer(fh).writerows(rows)
    print(f"{dst_name}: {len(rows) - 1} rows")


# 1. Operational tables reused directly (lowercased headers).
copy_lower("parties.csv", "raw_party.csv")
copy_lower("policies.csv", "raw_policy.csv")
copy_lower("brokers.csv", "raw_broker.csv")
copy_lower("claims.csv", "raw_claim.csv")
copy_lower("premium_transactions.csv", "raw_premium_transactions.csv")
copy_lower("reinsurance_treaties.csv", "raw_treaty.csv")
copy_lower("customers.csv", "raw_customers.csv")


# 2. Mainframe PLCYMSTR fixed-width flat feed (copybook mainframe/copybooks/PLCYMSTR.cpy).
#    Positions (1-based): POLICY_NO 1-18, CLIENT_NO 19-28, PRODUCT_CD 29-32,
#    INCEPT_DT_JUL 33-37 (YYDDD), ANNL_PREM 38-48 (pence, implied 2dp),
#    STATUS 49-50, POSTCODE 51-58, SURNAME 59-78.
def parse_plcymstr():
    out = [[
        "policy_no", "client_no", "product_cd", "incept_dt_jul",
        "annl_prem_pence", "status", "postcode", "surname",
    ]]
    with open(os.path.join(FEEDS, "PLCYMSTR_D260115.dat")) as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line.strip():
                continue
            out.append([
                line[0:18].strip(),
                line[18:28].strip(),
                line[28:32].strip(),
                line[32:37].strip(),
                line[37:48].strip(),
                line[48:50].strip(),
                line[50:58].strip(),
                line[58:78].strip(),
            ])
    with open(os.path.join(SEEDS, "raw_plcymstr.csv"), "w", newline="") as fh:
        csv.writer(fh).writerows(out)
    print(f"raw_plcymstr.csv: {len(out) - 1} rows")


# 3. LIFE400 POLMSTEX fixed-width feed (as400_life/feed_specs/POLMSTEX_feed_spec.md).
#    POLID 1-12, APPID 13-24, PRCDATE 25-30 (YYMMDD), PLANCD 31-35,
#    CNTRSTS 36-37, INSNAME 38-77, INSDOB 78-83 (YYMMDD), GENDER 84,
#    SUMASSURED 85-97 (implied 2dp), MODALPREM 98-110 (implied 2dp), PAYFREQ 111-112.
#    Dates are kept as raw YYMMDD integers exactly as they land in LIFE_DB.LIFE_POLICY.
def parse_polmstex():
    out = [[
        "life_policy_id", "application_id", "process_dt_yymmdd", "plan_cd",
        "contract_status", "insured_name", "insured_dob_yymmdd", "gender",
        "sum_assured", "modal_premium", "pay_freq", "matched_party_id",
    ]]
    with open(os.path.join(FEEDS, "POLMSTEX_D260115.dat")) as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line.strip():
                continue
            row = line
            def num(s):
                s = s.strip()
                return s if s else ""
            out.append([
                row[0:12].strip(),
                row[12:24].strip(),
                num(row[24:30]),
                row[30:35].strip(),
                row[35:37].strip(),
                row[37:77].strip(),
                num(row[77:83]),
                row[83:84].strip(),
                num(row[84:97]),
                num(row[97:110]),
                num(row[110:112]),
                "",  # matched_party_id: fuzzy match not resolved on the raw feed
            ])
    with open(os.path.join(SEEDS, "raw_life_policy.csv"), "w", newline="") as fh:
        csv.writer(fh).writerows(out)
    print(f"raw_life_policy.csv: {len(out) - 1} rows")


# 4. REF_DB.XREF_CLIENT_PARTY manual crosswalk. Synthesised from parties that
#    carry a legacy_customer_id (the ~55% populated APF crosswalk) so the demo
#    can exercise the identity-unification join. client_no is derived from the
#    legacy_customer_id to emulate the LEGACY_PAS CLIENT_NO domain.
def build_xref():
    out = [["client_no", "party_id", "match_method", "match_confidence",
            "loaded_by", "load_dt"]]
    with open(os.path.join(SRC, "parties.csv"), newline="") as fh:
        reader = csv.DictReader(fh)
        for r in reader:
            lci = (r.get("LEGACY_CUSTOMER_ID") or "").strip()
            if not lci:
                continue
            client_no = str(700000000 + int(lci))
            out.append([client_no, r["PARTY_ID"], "NINO", "0.95",
                        "mdm_batch", "2024-01-15"])
    with open(os.path.join(SEEDS, "raw_xref_client_party.csv"), "w", newline="") as fh:
        csv.writer(fh).writerows(out)
    print(f"raw_xref_client_party.csv: {len(out) - 1} rows")


parse_plcymstr()
parse_polmstex()
build_xref()
print("done")

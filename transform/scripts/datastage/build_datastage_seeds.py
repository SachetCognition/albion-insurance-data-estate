#!/usr/bin/env python3
"""Build the Session D (DataStage) dbt seeds from the legacy estate artefacts.

Run from the repository root:

    python3 transform/scripts/datastage/build_datastage_seeds.py

Inputs (all read-only legacy artefacts):
  datastage/source_data/{customer,Retail,product,transactiondata}.txt
      Sequential-file inputs of RETAIL_DATA_MART_Job.
  datastage/output_data/{RETAIL_DATA_MART,Count_Customers_Transactions}.txt
      Legacy job outputs, used verbatim as immutable golden baselines.
  data/inbound_feeds/POLMSTEX_D260115.dat
      FD-010 fixed-width LIFE400 extract (the input of the lost
      LIFE_POLICY_LOAD job).
  data/inbound_feeds/PLCYMSTR_D260115.dat
      FD-001 fixed-width LEGACY_PAS extract, the only surviving source of UK
      postcodes for the life book (ADDRMST itself was never migrated).

Outputs: transform/seeds/datastage/*.csv, plus the Session D rows of
transform/seeds/parity_allowlist.csv (rewritten idempotently; rows belonging
to other golden seeds are preserved untouched).

Notes
-----
* transactiondata.txt and POLMSTEX_D260115.dat are landed as raw records
  (one column) so that the record parsing, type conversion and reject
  handling that the DataStage sequential-file / column-import stages did
  stay visible in dbt SQL rather than being hidden in this script.
* golden_ds_life_policy_recon.csv is NOT a captured legacy output (the job
  export is lost). It is an independent reimplementation, in this script, of
  the documented legacy behaviour (FD-010 feed spec + LIFE_DB.LIFE_POLICY /
  V_LIFE_POLICY DDL, pivot year 40) used as the reconstruction baseline.
"""

from __future__ import annotations

import csv
import os
from decimal import Decimal

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SRC = os.path.join(REPO, "datastage", "source_data")
OUT = os.path.join(REPO, "datastage", "output_data")
FEEDS = os.path.join(REPO, "data", "inbound_feeds")
SEEDS = os.path.join(REPO, "transform", "seeds", "datastage")

# FD-010 POLMSTEX fixed-width layout (0-based python slices), per
# as400_life/feed_specs/POLMSTEX_feed_spec.md.
POLMSTEX_LAYOUT = {
    "polid": (0, 12),
    "appid": (12, 24),
    "prcdate": (24, 30),
    "plancd": (30, 35),
    "cntrsts": (35, 37),
    "insname": (37, 77),
    "insdob": (77, 83),
    "gender": (83, 84),
    "sumassured": (84, 99),
    "modalprem": (99, 114),
    "payfreq": (114, 116),
}


def read_lines(path: str) -> list[str]:
    with open(path, encoding="utf-8") as fh:
        return [line for line in fh.read().splitlines() if line.strip() != ""]


def copy_delimited(src: str, dest: str) -> int:
    """Copy a clean comma-delimited legacy file to a seed, re-quoting it."""
    rows = list(csv.reader(read_lines(src)))
    with open(dest, "w", newline="", encoding="utf-8") as fh:
        csv.writer(fh).writerows(rows)
    return len(rows) - 1


def landing_seed(src: str, dest: str) -> int:
    """Land a file as raw records (record_seq, raw_record), header excluded."""
    lines = read_lines(src)
    with open(dest, "w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh)
        writer.writerow(["record_seq", "raw_record"])
        for seq, line in enumerate(lines, start=1):
            writer.writerow([seq, line])
    return len(lines)


def life_policy_recon_baseline(src: str, dest: str) -> int:
    """Reconstructed LIFE_POLICY_LOAD / V_LIFE_POLICY baseline (pivot 40)."""
    rows = []
    for line in read_lines(src):
        f = {name: line[a:b] for name, (a, b) in POLMSTEX_LAYOUT.items()}
        dob_yymmdd = int(f["insdob"])
        # LIFE_DB.V_LIFE_POLICY: pivot 40 on the two-digit year.
        century = 19000000 if dob_yymmdd // 10000 >= 40 else 20000000
        sum_assured = Decimal(f["sumassured"]) / 100
        modal_premium = Decimal(f["modalprem"]) / 100
        pay_freq = int(f["payfreq"])
        rows.append(
            {
                "life_policy_id": f["polid"],
                "application_id": f["appid"],
                "process_dt_yymmdd": int(f["prcdate"]),
                "plan_cd": f["plancd"].strip(),
                "contract_status": f["cntrsts"],
                "insured_name": f["insname"].strip(),
                "insured_dob_yymmdd": dob_yymmdd,
                "gender": f["gender"],
                "sum_assured": f"{sum_assured:.2f}",
                "modal_premium": f"{modal_premium:.2f}",
                "pay_freq": pay_freq,
                # The legacy job's name+DOB fuzzy match left no crosswalk
                # table, no suspect queue and no documented match rate; the
                # baseline therefore carries it as unmatched (see README).
                "matched_party_id": "",
                "insured_dob_ccyymmdd": century + dob_yymmdd,
                "annualised_premium_in_force": f"{modal_premium * pay_freq:.2f}",
            }
        )
    with open(dest, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    return len(rows)


ALLOWLIST = os.path.join(REPO, "transform", "seeds", "parity_allowlist.csv")
DS_GOLDEN_SEEDS = ("golden_ds_life_policy_recon", "golden_ds_retail_data_mart")
INT32_MAX = 2147483647


def datastage_allowlist_rows() -> list[dict[str, str]]:
    """Documented intentional diffs of the Session D models vs their baselines."""
    rows: list[dict[str, str]] = []

    # DQR-052: canonical pivot 50 moves two-digit DOB years 40-50 from 19xx to
    # 20xx, so every life policy in that window differs from the pivot-40
    # reconstruction baseline.
    for line in read_lines(os.path.join(FEEDS, "POLMSTEX_D260115.dat")):
        f = {name: line[a:b] for name, (a, b) in POLMSTEX_LAYOUT.items()}
        yy = int(f["insdob"][:2])
        if 40 <= yy <= 50:
            rows.append(
                {
                    "golden_seed": "golden_ds_life_policy_recon",
                    "key_value": f["polid"],
                    "diff_reason": (
                        f"DQR-052 canonical pivot 50: DOB year {yy} moves 19{yy:02d}->20{yy:02d} "
                        "vs legacy LIFE400/V_LIFE_POLICY pivot 40"
                    ),
                }
            )

    # DS-OVERFLOW-01: the legacy RETAIL_DATA_MART_Job typed InvoiceDate as
    # int32, saturating these records at 2147483647; the port keeps the source
    # value.
    with open(os.path.join(OUT, "RETAIL_DATA_MART.txt"), encoding="utf-8") as fh:
        for rec in csv.DictReader(fh):
            if int(rec["InvoiceDate"]) == INT32_MAX:
                rows.append(
                    {
                        "golden_seed": "golden_ds_retail_data_mart",
                        "key_value": "|".join(
                            (rec["Stockid"], rec["Invoiceid"], rec["CustomerID"], rec["productid"])
                        ),
                        "diff_reason": (
                            "DS-OVERFLOW-01 legacy int32 InvoiceDate saturated at 2147483647; "
                            "port carries the source value as bigint"
                        ),
                    }
                )
    return rows


def refresh_parity_allowlist() -> int:
    """Replace only this session's rows in the shared parity allow-list."""
    with open(ALLOWLIST, encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        fields = reader.fieldnames or ["golden_seed", "key_value", "diff_reason"]
        kept = [r for r in reader if r["golden_seed"] not in DS_GOLDEN_SEEDS]
    mine = datastage_allowlist_rows()
    with open(ALLOWLIST, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        writer.writerows(kept + mine)
    return len(mine)


def main() -> None:
    os.makedirs(SEEDS, exist_ok=True)
    counts = {
        "raw_ds_customer.csv": copy_delimited(
            os.path.join(SRC, "customer.txt"), os.path.join(SEEDS, "raw_ds_customer.csv")
        ),
        "raw_ds_retail_store.csv": copy_delimited(
            os.path.join(SRC, "Retail.txt"), os.path.join(SEEDS, "raw_ds_retail_store.csv")
        ),
        "raw_ds_product.csv": copy_delimited(
            os.path.join(SRC, "product.txt"), os.path.join(SEEDS, "raw_ds_product.csv")
        ),
        "raw_ds_transaction_landing.csv": landing_seed(
            os.path.join(SRC, "transactiondata.txt"),
            os.path.join(SEEDS, "raw_ds_transaction_landing.csv"),
        ),
        "raw_ds_polmstex_landing.csv": landing_seed(
            os.path.join(FEEDS, "POLMSTEX_D260115.dat"),
            os.path.join(SEEDS, "raw_ds_polmstex_landing.csv"),
        ),
        "raw_ds_plcymstr_landing.csv": landing_seed(
            os.path.join(FEEDS, "PLCYMSTR_D260115.dat"),
            os.path.join(SEEDS, "raw_ds_plcymstr_landing.csv"),
        ),
        "golden_ds_retail_data_mart.csv": copy_delimited(
            os.path.join(OUT, "RETAIL_DATA_MART.txt"),
            os.path.join(SEEDS, "golden_ds_retail_data_mart.csv"),
        ),
        "golden_ds_count_customer_transactions.csv": copy_delimited(
            os.path.join(OUT, "Count_Customers_Transactions.txt"),
            os.path.join(SEEDS, "golden_ds_count_customer_transactions.csv"),
        ),
        "golden_ds_life_policy_recon.csv": life_policy_recon_baseline(
            os.path.join(FEEDS, "POLMSTEX_D260115.dat"),
            os.path.join(SEEDS, "golden_ds_life_policy_recon.csv"),
        ),
    }
    for name, n in counts.items():
        print(f"{name}: {n} rows")
    print(f"parity_allowlist.csv: {refresh_parity_allowlist()} Session D rows")


if __name__ == "__main__":
    main()

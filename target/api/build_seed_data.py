#!/usr/bin/env python3
"""Build a small, referentially-coherent seed dataset for the Spring Boot API's
in-memory (H2) test data layer, sampled from data/01_source_tables/.

Selects the first N policies, the parties they reference (plus a few LEGACY_PAS
crosswalk cases), and the claims for those policies, writing lowercase-header
CSVs into albion-app/src/test/resources/seed-data/ (also copied to main
resources so the demo app can boot with data).
"""
import csv
import os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, "data", "01_source_tables")
OUT_DIRS = [
    os.path.join(REPO, "target", "api", "albion-app", "src", "test", "resources", "seed-data"),
    os.path.join(REPO, "target", "api", "albion-app", "src", "main", "resources", "seed-data"),
]
for d in OUT_DIRS:
    os.makedirs(d, exist_ok=True)

N_POLICIES = 300


def read(name):
    with open(os.path.join(SRC, name), newline="") as fh:
        return list(csv.DictReader(fh))


policies = read("policies.csv")[:N_POLICIES]
policy_nos = {p["POLICY_NO"] for p in policies}
party_ids = {p["PARTY_ID"] for p in policies}

parties = [p for p in read("parties.csv") if p["PARTY_ID"] in party_ids]
claims = [c for c in read("claims.csv") if c["POLICY_NO"] in policy_nos]
# include claimant parties too
for c in claims:
    party_ids.add(c["CLAIMANT_PARTY_ID"])
parties = [p for p in read("parties.csv") if p["PARTY_ID"] in party_ids]


def write(name, rows, cols):
    for d in OUT_DIRS:
        with open(os.path.join(d, name), "w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow([c.lower() for c in cols])
            for r in rows:
                w.writerow([r.get(c, "") for c in cols])
    print(f"{name}: {len(rows)} rows")


write("parties.csv", parties,
      ["PARTY_ID", "PARTY_TYPE", "FIRST_NAME", "LAST_NAME", "BIRTH_DT", "NINO",
       "EMAIL_ADDR", "PHONE", "ADDR_LINE1", "CITY", "POSTCODE",
       "LEGACY_CUSTOMER_ID", "MDM_GOLDEN_FLAG", "CREATE_DT"])
write("policies.csv", policies,
      ["POLICY_NO", "PARTY_ID", "PRODUCT_CD", "PRODUCT_NAME", "BROKER_ID",
       "CHANNEL", "INCEPTION_DT", "EXPIRY_DT", "POLICY_STATUS",
       "ANNUAL_PREMIUM_GBP", "IPT_RATE", "PAYMENT_PLAN", "UW_YEAR",
       "SOURCE_SYSTEM"])
write("claims.csv", claims,
      ["CLAIM_NO", "POLICY_NO", "CLAIMANT_PARTY_ID", "LOSS_DT",
       "NOTIFICATION_DT", "CAUSE_CD", "CLAIM_STATUS", "INCURRED_AMT",
       "PAID_AMT", "OUTSTANDING_RESERVE", "FRAUD_FLAG", "HANDLER_ID",
       "SOURCE_SYSTEM"])
print("done")

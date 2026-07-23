# Group Customer & Marketing Insight — DataStage Estate
Built 2013 by an offshore team for the **Albion Retail Partnerships** programme
(affinity insurance sold through retail partners; the partner loyalty/"Bouns"
bonus programme feeds arrive as delimited files). Runs on InfoSphere DataStage
9.1 (server `IBMDSSERVER`, project `DS39`) — out of support since 2018.

Jobs (dsx exports in ./jobs):
- `RETAIL_DATA_MART_Job` — partner retail star schema (SCD on customer/store/product)
- `ACTIVATIONSALES_DATA_MART_Job` — policy activation vs partner sales mart
- `Bouns_Program_Job` — loyalty bonus qualification (typo enshrined in prod job name since 2013)
- `Count_Customer_Transactions_Job` — reconciliation counts

**`LIFE_POLICY_LOAD`** — loads FD-010 (LIFE400 POLMSTEX) into `LIFE_DB.LIFE_POLICY`
and fuzzy-matches life policyholders to group PARTY by name+DOB. **The .dsx export
for this job is lost** — it exists only in the prod repository; the contractor who
re-keyed it left in 2019. Change requests against it are refused by ops.

Identity note: partner loyalty files carry `CustomerID` (5-digit, partner-issued —
e.g. 17850). This **MKTG_CUST_ID is a 6th identifier scheme** and has never been
crosswalked to PARTY_ID or the APF CUSTOMER_ID; marketing dedupe is done ad hoc
in the marts on name+email.

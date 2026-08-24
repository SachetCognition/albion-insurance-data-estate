-- Session 0 harness smoke check: rebuilds the stg_customer_360 baseline
-- verbatim from the golden seed and proves the golden_parity test machinery
-- passes end-to-end on both engines. Session A replaces this with the real
-- BTEQ port under models/staging/bteq/.
select * from {{ ref('golden_stg_customer_360') }}

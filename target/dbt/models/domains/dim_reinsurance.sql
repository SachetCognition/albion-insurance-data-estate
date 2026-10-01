-- Domain: canonical REINSURANCE treaty dimension.
-- Line-of-business is mapped to the Solvency II LoB via the SINGLE canonical
-- seed (sii_lob_map), replacing the drifted duplicate mapping in
-- sas/regulatory/08_solvency_ii_qrt_prep.sas ($sii_lob format) vs Informatica
-- wf_REINSURANCE_BORDEREAUX_MONTHLY LKP_SII_LOB (PET wrongly 'Other motor').
with treaty as (
    select * from {{ ref('stg_treaty') }}
),

lob as (
    select * from {{ ref('sii_lob_map') }}
)

select
    t.treaty_id,
    t.treaty_type,
    t.line_of_business                                as product_cd,
    m.sii_line_of_business,
    t.reinsurer,
    t.cession_pct,
    t.retention_gbp,
    t.limit_gbp,
    t.uw_year
from treaty t
left join lob m on upper(m.product_cd) = t.line_of_business

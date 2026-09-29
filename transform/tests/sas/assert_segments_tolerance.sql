-- Statistical tolerance test for the ported PROC FASTCLUS model.
--
-- golden_parity already asserts full row/column parity with rounded scores;
-- this test states the tolerance explicitly and independently of the rounding
-- so the numbers cannot silently drift:
--   * scores       : absolute tolerance 0.01 (2 dp rounding of SAS `round(x, 0.01)`)
--   * segment_name : must match exactly — cluster *membership* is the business
--                    output; k-means initialisation may renumber clusters but
--                    must not move customers between labelled segments.
-- Rationale: models/python/README.md.

with joined as (

    select
        m.customer_id,
        m.segment_name,
        g.segment_name as golden_segment_name,
        m.lifetime_value_score,
        g.lifetime_value_score as golden_lifetime_value_score,
        m.engagement_score,
        g.engagement_score as golden_engagement_score,
        m.product_breadth_index,
        g.product_breadth_index as golden_product_breadth_index
    from {{ ref('sas_customer_segments') }} as m
    inner join {{ ref('golden_customer_segments') }} as g
        on m.customer_id = g.customer_id

)

select *
from joined
where
    segment_name != golden_segment_name
    or abs(lifetime_value_score - golden_lifetime_value_score) > 0.01
    or abs(engagement_score - golden_engagement_score) > 0.01
    or abs(product_breadth_index - golden_product_breadth_index) > 0.01

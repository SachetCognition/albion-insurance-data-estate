-- Statistical tolerance test for the ported PROC LOGISTIC scorecard.
--
-- Tolerances (rationale in models/python/README.md):
--   composite_risk_score / components : 0.01 absolute — the SAS DATA step
--       rounds the composite to 2 dp and the components are pure arithmetic,
--       so only floating-point noise is allowed.
--   probability_of_default            : 0.005 absolute — optimiser differences
--       between SAS PROC LOGISTIC (Fisher scoring) and sklearn lbfgs, plus the
--       absence of stepwise selection, make bit-exact equality meaningless.
--   risk_tier                         : exact — tier boundaries are business
--       rules applied to the rounded composite.

with joined as (

    select
        m.customer_id,
        m.risk_tier,
        g.risk_tier as golden_risk_tier,
        m.composite_risk_score,
        g.composite_risk_score as golden_composite_risk_score,
        m.probability_of_default,
        g.probability_of_default as golden_probability_of_default,
        m.credit_risk_component,
        g.credit_risk_component as golden_credit_risk_component,
        m.behaviour_risk_component,
        g.behaviour_risk_component as golden_behaviour_risk_component,
        m.velocity_risk_component,
        g.velocity_risk_component as golden_velocity_risk_component,
        m.bureau_score_component,
        g.bureau_score_component as golden_bureau_score_component,
        m.payment_history_component,
        g.payment_history_component as golden_payment_history_component
    from {{ ref('sas_customer_risk_scores') }} as m
    inner join {{ ref('golden_customer_risk_scores') }} as g
        on m.customer_id = g.customer_id

)

select *
from joined
where
    risk_tier != golden_risk_tier
    or abs(composite_risk_score - golden_composite_risk_score) > 0.01
    or abs(probability_of_default - golden_probability_of_default) > 0.005
    or abs(credit_risk_component - golden_credit_risk_component) > 0.01
    or abs(behaviour_risk_component - golden_behaviour_risk_component) > 0.01
    or abs(velocity_risk_component - golden_velocity_risk_component) > 0.01
    or abs(bureau_score_component - golden_bureau_score_component) > 0.01
    or abs(payment_history_component - golden_payment_history_component) > 0.01

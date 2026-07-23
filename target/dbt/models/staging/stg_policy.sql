-- Staging: POLICY_ADMIN_DB.POLICY (POLARIS + LEGACY_PAS union).
-- POLICY_NO normalised once to the canonical ALB-XXX-9999999 form (replaces the
-- inline re-keying duplicated in api_legacy/plsql/pkg_policy_inquiry.sql and the
-- three policy-number formats noted in docs/feed_inventory.md).
with src as (
    select * from {{ source('raw', 'policy') }}
)
select
    {{ normalise_policy_no('policy_no') }}            as policy_no,
    policy_no                                         as policy_no_source,
    party_id,
    upper(trim(product_cd))                           as product_cd,
    product_name,
    broker_id,
    channel,
    try_to_date(to_varchar(inception_dt))             as inception_dt,
    try_to_date(to_varchar(expiry_dt))                as expiry_dt,
    upper(trim(policy_status))                        as policy_status,
    try_to_decimal(to_varchar(annual_premium_gbp), 12, 2) as annual_premium_gbp,
    try_to_decimal(to_varchar(ipt_rate), 5, 4)        as ipt_rate,
    payment_plan,
    try_to_number(to_varchar(uw_year))               as uw_year,
    upper(trim(source_system))                        as source_system
from src

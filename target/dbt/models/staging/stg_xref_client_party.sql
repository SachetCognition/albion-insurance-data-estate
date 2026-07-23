-- Staging: REF_DB.XREF_CLIENT_PARTY manual crosswalk (LEGACY_PAS CLIENT_NO ->
-- POLARIS PARTY_ID). One of the two partial crosswalks used to unify identity
-- (the other being PARTY.LEGACY_CUSTOMER_ID). See docs/feed_inventory.md.
with src as (
    select * from {{ source('raw', 'xref_client_party') }}
)
select
    try_to_number(to_varchar(client_no))              as client_no,
    party_id,
    upper(trim(match_method))                         as match_method,
    try_to_decimal(to_varchar(match_confidence), 3, 2) as match_confidence,
    loaded_by,
    try_to_date(to_varchar(load_dt))                  as load_dt
from src

-- Staging: REINSURANCE_DB.TREATY.
with src as (
    select * from {{ source('raw', 'treaty') }}
)
select
    treaty_id,
    upper(trim(treaty_type))                          as treaty_type,
    upper(trim(line_of_business))                     as line_of_business,
    reinsurer,
    try_to_decimal(to_varchar(cession_pct), 5, 1)     as cession_pct,
    try_to_decimal(to_varchar(retention_gbp), 14, 0)  as retention_gbp,
    try_to_decimal(to_varchar(limit_gbp), 16, 0)      as limit_gbp,
    try_to_number(to_varchar(uw_year))               as uw_year
from src

-- Unit test: party_canonical_key precedence (MDM golden first, NINO last).
with cases as (
    select 1 as n
)

select *
from cases
where
    {{ party_canonical_key(party_id="'P0000001'", customer_id="'42'") }} <> 'PARTY:P0000001'
    or {{ party_canonical_key(party_id='null', customer_id="'42'") }} <> 'APF:42'
    or {{ party_canonical_key(client_no="'C77'", nino="'we503906b'") }} <> 'LIFE400:C77'
    or {{ party_canonical_key(nino="'we503906b'") }} <> 'NINO:WE503906B'

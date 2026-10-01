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
    -- full precedence chain: PARTY wins over all five other schemes
    or {{ party_canonical_key(
        party_id="'P1'",
        legacy_customer_id="'L1'",
        customer_id="'42'",
        client_no="'C1'",
        mktg_cust_id="'M1'",
        nino="'we503906b'"
    ) }} <> 'PARTY:P1'
    -- LEGACY outranks APF; MKTG outranks NINO
    or {{ party_canonical_key(legacy_customer_id="'L1'", customer_id="'42'") }} <> 'LEGACY:L1'
    or {{ party_canonical_key(mktg_cust_id="'M1'", nino="'we503906b'") }} <> 'MKTG:M1'
    -- blank/whitespace ids are treated as absent and fall through
    or {{ party_canonical_key(party_id="'  '", customer_id="'42'") }} <> 'APF:42'
    -- values are trimmed before prefixing
    or {{ party_canonical_key(party_id="' P0000001 '") }} <> 'PARTY:P0000001'
    -- no usable identifier at all yields null, never a bare prefix
    or {{ party_canonical_key(party_id='null', nino="'  '") }} is not null

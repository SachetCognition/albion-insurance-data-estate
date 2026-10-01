{#-
  Identity / party crosswalk — canonical key derivation STUB (DQR-041).

  The estate has six identity silos:
    1. PARTY_ID            MDM golden record          (parties.csv, Informatica MDM)
    2. LEGACY_CUSTOMER_ID  pre-MDM insurance customer (parties.LEGACY_CUSTOMER_ID)
    3. customer_id         APF banking customer       (customers.csv, BTEQ/SAS book)
    4. CLIENT_NO           LIFE400 life book          (AS/400 CLNTMST — keyless in DWH)
    5. MKTG_CUST_ID        marketing platform         (never crosswalked in legacy)
    6. NINO                natural-person fallback    (DQR-021: masked outside ops)

  party_canonical_key() returns a deterministic, scheme-prefixed key with a
  fixed precedence (MDM golden first, NINO last-resort). It is deliberately a
  simple precedence coalesce for now: Session C owns full MDM survivorship on
  top of it, and Session D uses it for the life-book party-resolution
  backfill. Both MUST call this macro rather than deriving their own key so
  match-rate movements vs the legacy ~55% stay attributable.
-#}

{% macro party_canonical_key(
    party_id=none,
    legacy_customer_id=none,
    customer_id=none,
    client_no=none,
    mktg_cust_id=none,
    nino=none
) %}
    coalesce(
        {% if party_id %}'PARTY:' || nullif(trim(cast({{ party_id }} as varchar)), ''),{% endif %}
        {% if legacy_customer_id %}'LEGACY:' || nullif(trim(cast({{ legacy_customer_id }} as varchar)), ''),{% endif %}
        {% if customer_id %}'APF:' || nullif(trim(cast({{ customer_id }} as varchar)), ''),{% endif %}
        {% if client_no %}'LIFE400:' || nullif(trim(cast({{ client_no }} as varchar)), ''),{% endif %}
        {% if mktg_cust_id %}'MKTG:' || nullif(trim(cast({{ mktg_cust_id }} as varchar)), ''),{% endif %}
        {% if nino %}'NINO:' || nullif(trim(upper(cast({{ nino }} as varchar))), ''),{% endif %}
        null
    )
{% endmacro %}

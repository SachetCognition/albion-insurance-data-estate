{#
    Single canonical standardisation helpers. Each replaces several drifted
    legacy implementations; see tests/README.md for the full mapping.
#}

{#
    Canonical UK postcode standardisation (DQR-014).
    Replaces the FOUR divergent implementations:
      * Informatica mplt_DQ_PARTY_STANDARDISE (auto-repairs space, then regex)
      * BTEQ 04_stg_policy_360           (requires embedded space, first-char alpha)
      * SAS sas/macros/check_uk_postcode (case-sensitive PRX, rejects lowercase)
      * COBOL PLCYMSTR 88-level          (first-char-alpha only, PR4471)
    We uppercase, collapse whitespace, and re-insert the single space before the
    3-char inward code. (The 5th "variant" is LIFE400 having NO postcode field;
    that is handled as a documented not_null exemption in the domain layer, not
    here — see tests/README.md.)
#}
{% macro standardise_postcode(col) %}
    (
        case
            when {{ col }} is null or trim({{ col }}) = '' then null
            else regexp_replace(
                     upper(regexp_replace(trim({{ col }}), '\\s+', '')),
                     '^(.{2,4})(.{3})$',
                     '\\1 \\2'
                 )
        end
    )
{% endmacro %}


{#
    Canonical email normalisation (DQR-007). Replaces:
      * Informatica EXP_EMAIL_DQ (regex + lowercase)
      * BTEQ 04_stg_policy_360   (contains '@' only)
      * APF banking pipeline     (no validation at all)
    We lowercase + trim once here; the FORMAT test lives in tests (schema.yml).
#}
{% macro standardise_email(col) %}
    (
        case
            when {{ col }} is null or trim({{ col }}) = '' then null
            else lower(trim({{ col }}))
        end
    )
{% endmacro %}


{#
    Pence implied-decimal -> GBP DECIMAL (mainframe PLCYMSTR ANNL_PREM PIC 9(9)V99
    stored in pence; LIFE400 SUMASSURED / MODALPREM implied 2dp). Replaces the
    ad-hoc `/ 100` scattered through BTEQ/SAS.
#}
{% macro pence_to_gbp(col) %}
    (try_to_decimal(to_varchar({{ col }})) / 100.0)
{% endmacro %}


{#
    Text money with '£' and thousands separators (broker bordereaux, e.g.
    "£81,518.98") -> GBP DECIMAL. Replaces inline bordereaux parsing.
#}
{% macro gbp_text_to_decimal(col) %}
    try_to_decimal(
        regexp_replace({{ col }}, '[^0-9.\\-]', ''),
        38, 2
    )
{% endmacro %}


{#
    NINO masking (DQR-021 / AR-118). Applied in the DOMAIN layer so NO unmasked
    NINO ever reaches an analytical consumer. Replaces:
      * Informatica EXP_NINO_MASK (marts only)
      * SAS sas/macros/mask_nino.sas (output only; fraud pipeline joined RAW NINO)
    Format: first 2 + '*****' + last 2 (matches the legacy SAS mask shape).
#}
{% macro mask_nino(col) %}
    (
        case
            when {{ col }} is null or trim({{ col }}) = '' then null
            else left({{ col }}, 2) || '*****' || right({{ col }}, 2)
        end
    )
{% endmacro %}


{#
    Canonical policy-number normalisation. The mainframe PLCYMSTR feed strips
    hyphens (ALBPET0003278) vs the POLARIS format (ALB-PET-0000001); broker
    bordereaux arrive re-keyed as AL/PET-0001559. This re-keying is duplicated
    inline in api_legacy/plsql/pkg_policy_inquiry.sql (the "4th place"). We do it
    ONCE. Canonical form: ALB-XXX-9999999.
#}
{% macro normalise_policy_no(col) %}
    (
        case
            when {{ col }} is null then null
            -- bordereaux AL/PET-0001559 -> ALB-PET-0001559
            when regexp_like(upper(trim({{ col }})), '^AL/[A-Z]{3}-[0-9]+$')
                then regexp_replace(upper(trim({{ col }})), '^AL/([A-Z]{3})-([0-9]+)$', 'ALB-\\1-\\2')
            -- mainframe ALBPET0003278 -> ALB-PET-0003278
            when regexp_like(upper(trim({{ col }})), '^ALB[A-Z]{3}[0-9]+$')
                then regexp_replace(upper(trim({{ col }})), '^ALB([A-Z]{3})([0-9]+)$', 'ALB-\\1-\\2')
            else upper(trim({{ col }}))
        end
    )
{% endmacro %}

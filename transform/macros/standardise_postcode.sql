{#-
  DQR-014 — UK postcode standardisation. THE single canonical implementation.

  The legacy estate had five disagreeing variants (dq_rules/dq_rules_registry.csv):
    1. Informatica mplt_DQ_PARTY_STANDARDISE: auto-repairs missing space, then regex.
    2. BTEQ 04_stg_policy_360: requires a space + first char alpha only.
    3. SAS check_uk_postcode.sas: full regex but case-SENSITIVE (never registered).
    4. COBOL PLCYMSTR 88-level: first char alpha only (PR4471).
    5. LIFE400: no postcode field at all (addresses stranded in ADDRMST).

  Converged rule (Data Governance sign-off pending, documented intentional
  change vs variants 2-5):
    - upper-case + trim (fixes SAS case-sensitivity),
    - auto-repair: strip internal whitespace and re-insert the single space
      before the 3-char inward code when the compact form is 5-7 chars
      (adopts the Informatica repair behaviour),
    - validate against the full UK format regex.

  standardise_postcode(expr) -> repaired 'OUTWARD INWARD' string (original
    trimmed/uppered value if it cannot be repaired).
  is_valid_uk_postcode(expr) -> boolean, applied AFTER standardisation.
-#}

{% macro standardise_postcode(expr) %}
    case
        when {{ expr }} is null then null
        when length(replace(upper(trim({{ expr }})), ' ', '')) between 5 and 7
            then substr(
                replace(upper(trim({{ expr }})), ' ', ''),
                1,
                length(replace(upper(trim({{ expr }})), ' ', '')) - 3
            )
            || ' '
            || substr(
                replace(upper(trim({{ expr }})), ' ', ''),
                length(replace(upper(trim({{ expr }})), ' ', '')) - 2
            )
        else upper(trim({{ expr }}))
    end
{% endmacro %}

{% macro is_valid_uk_postcode(expr) %}
    coalesce(
        {{ regexp_full_match(
            standardise_postcode(expr),
            '[A-Z]{1,2}[0-9][A-Z0-9]? [0-9][A-Z]{2}'
        ) }},
        false
    )
{% endmacro %}

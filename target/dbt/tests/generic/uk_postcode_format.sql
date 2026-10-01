{#
    DQR-014 — UK postcode valid.
    ONE canonical UK-postcode regex test, run against the postcode standardised
    once in staging (macro standardise_postcode). Replaces the FOUR divergent
    validators (Informatica auto-repair regex; BTEQ requires-space; SAS
    case-sensitive PRX; COBOL first-char-alpha PR4471).
    The 5th "variant" — LIFE400 has NO postcode field — is handled as a
    documented not_null EXEMPTION at the domain layer (LIFE400 parties carry a
    null postcode by design; see tests/README.md), so nulls PASS this test.
    Returns rows that FAIL.
#}
{% test uk_postcode_format(model, column_name) %}
select {{ column_name }} as failing_value
from {{ model }}
where {{ column_name }} is not null
  and not regexp_like({{ column_name }}, '^[A-Z]{1,2}[0-9][A-Z0-9]? [0-9][A-Z]{2}$')
{% endtest %}

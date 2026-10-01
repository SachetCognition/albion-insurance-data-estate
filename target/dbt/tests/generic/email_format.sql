{#
    DQR-007 — Email format valid.
    Single canonical email format test. Replaces the divergent implementations:
      * Informatica EXP_EMAIL_DQ (regex + lowercase)
      * BTEQ 04_stg_policy_360   (contains '@' only)
      * APF banking pipeline     (no validation at all)
    Emails are lowercased/trimmed in staging (macro standardise_email); this test
    asserts the syntactic format. Returns rows that FAIL.
#}
{% test email_format(model, column_name) %}
select {{ column_name }} as failing_value
from {{ model }}
where {{ column_name }} is not null
  and not regexp_like({{ column_name }}, '^[a-z0-9._%+\\-]+@[a-z0-9.\\-]+\\.[a-z]{2,}$')
{% endtest %}

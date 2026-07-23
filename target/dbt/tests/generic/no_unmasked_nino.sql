{#
    DQR-021 / AR-118 — no unmasked NINO in analytical stores.
    Asserts that a column contains no value shaped like a full, unmasked UK
    National Insurance number (2 letters + 6 digits + 1 letter). NINO is masked
    in the domain layer (macro mask_nino) and NINO_RAW is never selected past
    staging, closing the fraud-pipeline raw-join bypass (AR-118). Applied to the
    masked column and to any free-text column that might leak one.
    Returns rows that FAIL.
#}
{% test no_unmasked_nino(model, column_name) %}
select {{ column_name }} as failing_value
from {{ model }}
where {{ column_name }} is not null
  and regexp_like(upper({{ column_name }}), '^[A-Z]{2}[0-9]{6}[A-Z]$')
{% endtest %}

{#
    DQR-052 — date century derivation consistent (single pivot).
    Asserts a derived date column was resolved with the single agreed pivot:
      * no year in the future (the failure mode of a too-low pivot), and
      * no implausibly old year < 1900 (the +100y DOB shift failure mode).
    This is the property guaranteed by macros/albion_dates.sql (sliding pivot),
    and would catch any regression to the legacy 49/50/40 divergence.
    Returns rows that FAIL.
#}
{% test single_pivot_date(model, column_name) %}
select {{ column_name }} as failing_value
from {{ model }}
where {{ column_name }} is not null
  and (
        {{ column_name }} > current_date()
     or year({{ column_name }}) < 1900
  )
{% endtest %}

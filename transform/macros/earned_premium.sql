{#-
  Earned premium — ONE canonical implementation for the whole estate.

  Legacy drift (see teradata/bteq/06_stg_earned_premium.bteq header):
    - Finance  (BTEQ 06):                straight-line monthly 1/12ths
    - Actuarial (SAS 06_reserving_triangles): daily 365ths
    - DWH recon (Informatica wf_BILLING_PREMIUM_RECON): 1/24ths
  Month-end reconciliation between the three was manual (Xls, J.Mercer).

  CANONICAL METHOD = 'twelfths' (straight-line monthly 1/12ths, the Finance
  figure). It replicates the BTEQ arithmetic exactly:
      earned = annual_premium * least(12, greatest(0, floor(days/30))) / 12

  The 365ths and 24ths variants remain available behind the `method` argument
  so sessions B (actuarial) and C (billing recon) call THIS macro instead of
  re-implementing their own copy — any figure produced with a non-default
  method must be labelled as such in the model and documented as an
  intentional diff where it feeds a golden-parity comparison.
    - 'day_365ths':       earned = annual * least(365, greatest(0, days)) / 365
    - 'twenty_fourths':   earned = annual * least(24, greatest(0, 2*floor(days/30) + 1)) / 24
                          (mid-month assumption on the month of inception)

  unearned_premium() is always annual minus the same-method earned figure.
-#}

{% macro earned_premium(annual_premium, inception_dt, as_at_dt, method='twelfths') %}
    {%- set days = days_between(inception_dt, as_at_dt) -%}
    {%- if method == 'twelfths' -%}
        cast({{ annual_premium }} * least(12, greatest(0, floor(({{ days }}) / 30.0))) / 12.0 as decimal(12, 2))
    {%- elif method == 'day_365ths' -%}
        cast({{ annual_premium }} * least(365, greatest(0, {{ days }})) / 365.0 as decimal(12, 2))
    {%- elif method == 'twenty_fourths' -%}
        cast({{ annual_premium }} * least(24, greatest(0, 2 * floor(({{ days }}) / 30.0) + 1)) / 24.0 as decimal(12, 2))
    {%- else -%}
        {{ exceptions.raise_compiler_error("earned_premium: unknown method '" ~ method ~ "'. Use 'twelfths' (canonical), 'day_365ths' or 'twenty_fourths'.") }}
    {%- endif -%}
{% endmacro %}

{% macro unearned_premium(annual_premium, inception_dt, as_at_dt, method='twelfths') %}
    cast({{ annual_premium }} - {{ earned_premium(annual_premium, inception_dt, as_at_dt, method) }} as decimal(12, 2))
{% endmacro %}

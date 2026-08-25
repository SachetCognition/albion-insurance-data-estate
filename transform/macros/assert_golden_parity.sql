{#-
  assert_golden_parity — reusable before/after reconciliation test.

  Diffs a rebuilt model against its immutable GOLDEN.BASELINE seed at full
  row/column parity (both directions), with:
    - exclude_columns: volatile columns excluded from comparison
      (e.g. load_ts, as_at_dt — document every exclusion in the model yml);
    - round_columns:   {column: decimals} — rounds both sides before
      comparing, for float/statistical columns where a documented numeric
      tolerance replaces exact match;
    - allow-list:      seeds/parity_allowlist.csv — documented INTENTIONAL
      diffs (converged DQ rules, pivot-year changes, ...). Rows are keyed by
      (golden_seed, key_value) where key_value is the pipe-joined key_columns.

  Usage (schema yml):
    data_tests:
      - golden_parity:
          golden_seed: golden_stg_customer_360
          key_columns: ['customer_id']
          exclude_columns: ['load_ts']
          round_columns: {'total_balance': 2}

  The test fails if any undocumented row exists in the model but not the
  baseline ('model_only') or vice versa ('golden_only').
-#}

{% test golden_parity(model, golden_seed, key_columns, exclude_columns=[], round_columns={}) %}

{%- set golden_rel = ref(golden_seed) -%}
{%- set allowlist_rel = ref('parity_allowlist') -%}

{%- if execute -%}
    {%- set exclude_lower = exclude_columns | map('lower') | list -%}
    {%- set round_lower = {} -%}
    {%- for k, v in round_columns.items() -%}
        {%- do round_lower.update({k | lower: v}) -%}
    {%- endfor -%}

    {%- set compare_exprs = [] -%}
    {%- for col in adapter.get_columns_in_relation(golden_rel) -%}
        {%- set c = col.name | lower -%}
        {%- if c not in exclude_lower -%}
            {%- if c in round_lower -%}
                {%- do compare_exprs.append('round(cast(' ~ c ~ ' as double), ' ~ round_lower[c] ~ ') as ' ~ c) -%}
            {%- else -%}
                {%- do compare_exprs.append(c) -%}
            {%- endif -%}
        {%- endif -%}
    {%- endfor -%}
    {%- set select_list = compare_exprs | join(',\n        ') -%}
    {%- set key_parts = [] -%}
    {%- for k in key_columns -%}
        {%- do key_parts.append('cast(' ~ (k | lower) ~ ' as varchar)') -%}
    {%- endfor -%}
    {%- set key_expr = key_parts | join(" || '|' || ") -%}

with model_side as (
    select
        {{ select_list }}
    from {{ model }}
),

golden_side as (
    select
        {{ select_list }}
    from {{ golden_rel }}
),

diffs as (
    select 'model_only' as diff_side, * from (
        select * from model_side
        except
        select * from golden_side
    ) as d1

    union all

    select 'golden_only' as diff_side, * from (
        select * from golden_side
        except
        select * from model_side
    ) as d2
),

allowed as (
    select key_value
    from {{ allowlist_rel }}
    where lower(golden_seed) = '{{ golden_seed | lower }}'
)

select *
from diffs
where {{ key_expr }} not in (select key_value from allowed)

{%- else -%}
select 1 as placeholder where 1 = 0
{%- endif -%}

{% endtest %}

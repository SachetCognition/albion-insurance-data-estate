{#-
  Cross-engine helpers so every shared macro renders correctly on both the
  free local/CI engine (duckdb) and the live warehouse (snowflake).
-#}

{% macro regexp_full_match(expr, pattern) %}
    {%- if target.type == 'snowflake' -%}
        regexp_like({{ expr }}, '{{ pattern }}')
    {%- else -%}
        regexp_full_match({{ expr }}, '{{ pattern }}')
    {%- endif -%}
{% endmacro %}

{% macro days_between(start_dt, end_dt) %}
    {%- if target.type == 'snowflake' -%}
        datediff('day', {{ start_dt }}, {{ end_dt }})
    {%- else -%}
        date_diff('day', cast({{ start_dt }} as date), cast({{ end_dt }} as date))
    {%- endif -%}
{% endmacro %}

{#- Route models to RAW/GOLDEN databases on snowflake; duckdb has a single
    database file, so the database override collapses into the schema name
    (e.g. GOLDEN.STAGING -> schema golden_staging). -#}

{% macro generate_database_name(custom_database_name, node) -%}
    {%- if target.type == 'duckdb' -%}
        {{ target.database }}
    {%- elif custom_database_name is none -%}
        {{ target.database }}
    {%- else -%}
        {{ custom_database_name | trim }}
    {%- endif -%}
{%- endmacro %}

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set schema = custom_schema_name if custom_schema_name is not none else target.schema -%}
    {%- if target.type == 'duckdb' and node.config.database -%}
        {{ (node.config.database ~ '_' ~ schema) | lower | trim }}
    {%- else -%}
        {{ schema | trim }}
    {%- endif -%}
{%- endmacro %}

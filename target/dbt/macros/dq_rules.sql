{#-
    Canonical, single-implementation DQ rules. These macros are THE governed
    definition of DQR-007 and DQR-014 (see dq_rules/dq_rules_registry.csv) and
    are used both to derive the *_dq_status columns in the policy_360 mart and
    by the generic dbt tests in tests/generic/.
-#}

{% macro dqr_007_is_valid_email(column) %}
    (
        {{ column }} is not null
        and regexp_matches(trim({{ column }}), '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
    )
{% endmacro %}

{% macro dqr_014_is_valid_uk_postcode(column) %}
    (
        {{ column }} is not null
        and regexp_matches(upper(trim({{ column }})), '^[A-Z]{1,2}[0-9][A-Z0-9]? [0-9][A-Z]{2}$')
    )
{% endmacro %}

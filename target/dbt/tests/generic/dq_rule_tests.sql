{% test dqr_007_valid_email(model, column_name) %}
    select {{ column_name }}
    from {{ model }}
    where not {{ dqr_007_is_valid_email(column_name) }}
{% endtest %}

{% test dqr_014_valid_uk_postcode(model, column_name) %}
    select {{ column_name }}
    from {{ model }}
    where not {{ dqr_014_is_valid_uk_postcode(column_name) }}
{% endtest %}

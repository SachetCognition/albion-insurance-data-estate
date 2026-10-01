{#
    Canonical date handling for the whole Albion estate.

    Replaces the THREE divergent Y2K pivots (DQR-052):
      * Informatica  EXP_POLICY_DATES / EXP_CLAIM_DATES  -> pivot 49
      * SAS          sas/macros/julian_to_date.sas        -> pivot 50
      * LIFE400/DataStage / teradata/ddl/04_life_db.sql
        (V_LIFE_POLICY) & as400_life POLMSTEX             -> pivot 40

    ...with ONE agreed rule. A two-digit year `yy` resolves to 2000+yy when that
    year is <= the current calendar year, otherwise 1900+yy. This is a single,
    documented, self-consistent pivot that guarantees:
      * no derived date is in the future (supports DQR-052 / DQR-033), and
      * no date-of-birth is shifted +100 years.
#}

{% macro resolve_century_year(two_digit_year_expr) %}
    (
        case
            when 2000 + {{ two_digit_year_expr }} <= year(current_date())
            then 2000 + {{ two_digit_year_expr }}
            else 1900 + {{ two_digit_year_expr }}
        end
    )
{% endmacro %}


{#
    Parse DD/MM/YYYY text dates (POLARIS PARTY.BIRTH_DT, CLAIMS_DB.CLAIM.LOSS_DT).
    Replaces the DD/MM vs MM/DD split-brain: Informatica wf_CLAIMS_FNOL_INTRADAY
    EXP_CLAIM_DATES parses Guidewire loss dates as MM/DD/YYYY (INC0067812) while
    BTEQ 05_stg_claims_summary treats them as DD/MM/YYYY. We standardise on the
    UK DD/MM/YYYY interpretation once, here.
#}
{% macro parse_ddmmyyyy_text(col) %}
    try_to_date(trim({{ col }}), 'DD/MM/YYYY')
{% endmacro %}


{#
    Convert a Julian YYDDD string (mainframe PLCYMSTR INCEPT_DT) to a DATE using
    the single agreed pivot. Replaces Informatica EXP_POLICY_DATES (pivot 49),
    BTEQ 04_stg_policy_360 and SAS %julian_to_date (pivot 50).
#}
{% macro julian_yyddd_to_date(col) %}
    (
        dateadd(
            'day',
            try_to_number(substr({{ col }}, 3, 3)) - 1,
            date_from_parts(
                {{ resolve_century_year("try_to_number(substr(" ~ col ~ ", 1, 2))") }},
                1, 1
            )
        )
    )
{% endmacro %}


{#
    Convert a 6-digit YYMMDD integer/string (LIFE400 POLMSTEX INSDOB / PRCDATE,
    landed in LIFE_DB.LIFE_POLICY as INTEGER) to a DATE using the single agreed
    pivot. Replaces the LIFE_DB.V_LIFE_POLICY pivot-40 CASE expression.
#}
{% macro yymmdd_to_date(col) %}
    (
        try_to_date(
            to_varchar(
                {{ resolve_century_year("try_to_number(substr(lpad(to_varchar(" ~ col ~ "), 6, '0'), 1, 2))") }}
                * 10000
                + try_to_number(substr(lpad(to_varchar({{ col }}), 6, '0'), 3, 4))
            ),
            'YYYYMMDD'
        )
    )
{% endmacro %}

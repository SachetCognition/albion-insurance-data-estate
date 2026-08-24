{#-
  DQR-052 — Julian YYDDD date conversion with ONE group pivot year.

  Legacy pivots diverged: Informatica EXP_POLICY_DATES used 49, SAS
  julian_to_date.sas used 50, LIFE400/DataStage/V_LIFE_POLICY used 40.

  Canonical group pivot: 50 (two-digit years 00-50 -> 20xx, 51-99 -> 19xx),
  matching the SAS actuarial copy. Intentional diffs vs legacy:
    - Informatica-derived dates for yy = 50 move from 1950 to 2050
      (only MOT telematics pre-registrations are affected today).
    - LIFE400-derived dates for yy in 41-50 move from 19xx to 20xx.
  Any parity fallout must be recorded in the seed
  seeds/parity_allowlist.csv rather than by changing this pivot.

  julian_to_date(expr) — expr is a 5-char YYDDD string (or number).
-#}

{% macro julian_to_date(expr, pivot=50) %}
    case
        when {{ expr }} is null then null
        else
            cast(
                cast(
                    case
                        when cast(substr(lpad(cast({{ expr }} as varchar), 5, '0'), 1, 2) as integer) <= {{ pivot }}
                            then 2000 + cast(substr(lpad(cast({{ expr }} as varchar), 5, '0'), 1, 2) as integer)
                        else 1900 + cast(substr(lpad(cast({{ expr }} as varchar), 5, '0'), 1, 2) as integer)
                    end as varchar
                ) || '-01-01' as date
            )
            + (cast(substr(lpad(cast({{ expr }} as varchar), 5, '0'), 3, 3) as integer) - 1)
    end
{% endmacro %}

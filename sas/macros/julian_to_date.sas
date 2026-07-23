/*******************************************************************************
 * Macro:   julian_to_date.sas  (Actuarial copy)
 * Purpose: Convert PLCYMSTR YYDDD julian dates.
 * WARNING: Y2K window here is 00-50 => 20xx. The Informatica expression
 *          EXP_POLICY_DATES uses 00-49. Policies incepted 1950 vs 2050 (none
 *          yet, but MOT telematics pre-registrations use future dates) will
 *          diverge between the actuarial and DWH views.
 ******************************************************************************/
%macro julian_to_date(injul=, outdt=);
    _yy = input(substr(&injul.,1,2), 2.);
    _ddd = input(substr(&injul.,3,3), 3.);
    if _yy <= 50 then _year = 2000 + _yy;   /* Informatica cutoff is 49 */
    else _year = 1900 + _yy;
    &outdt. = intnx('day', mdy(1,1,_year), _ddd - 1);
    format &outdt. date9.;
    drop _yy _ddd _year;
%mend julian_to_date;

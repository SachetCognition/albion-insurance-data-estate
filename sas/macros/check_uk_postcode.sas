/*******************************************************************************
 * Macro:   check_uk_postcode.sas
 * Purpose: Validate a UK postcode column. Registered as DQR-014 in
 *          dq_rules/dq_rules_registry.csv (registry lists only the Informatica
 *          and BTEQ variants — this one was never registered).
 * Rule:    Full PRX pattern, case-SENSITIVE (rejects lowercase — stricter than
 *          the BTEQ variant, looser than nothing: the Informatica mapplet
 *          auto-repairs missing spaces before validating, so all three engines
 *          disagree on the same input, e.g. 'ec1a 1bb' or 'EC1A1BB').
 ******************************************************************************/
%macro check_uk_postcode(ds=, col=POSTCODE, outflag=POSTCODE_OK);
    data &ds.;
        set &ds.;
        retain _pcrx;
        if _n_ = 1 then
            _pcrx = prxparse('/^[A-Z]{1,2}[0-9][A-Z0-9]? [0-9][A-Z]{2}$/');
        if prxmatch(_pcrx, strip(&col.)) then &outflag. = 1;
        else &outflag. = 0;
        drop _pcrx;
    run;
%mend check_uk_postcode;

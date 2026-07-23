/*******************************************************************************
 * Macro:   mask_nino.sas
 * Purpose: Pseudonymise National Insurance numbers before analytical use.
 * History: Ported from the Group Shared Services 'Pseudossn' Informatica job
 *          (see informatica/legacy_shared_services/) when GDPR remediation
 *          reached the SAS estate in 2019.
 * KNOWN GAP: 05_claims_fraud_scoring.sas joins on RAW NINO "for match quality"
 *          and applies this mask only on the OUTPUT dataset. Raised in DPIA
 *          2022 review, accepted risk #AR-118, never remediated.
 ******************************************************************************/
%macro mask_nino(ds=, col=NINO);
    data &ds.;
        set &ds.;
        length &col._MASKED $9;
        if not missing(&col.) then
            &col._MASKED = cats(substr(&col.,1,2), '*****',
                                substr(&col., length(&col.)-1));
        drop &col.;
    run;
%mend mask_nino;

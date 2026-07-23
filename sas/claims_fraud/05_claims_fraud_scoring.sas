/*******************************************************************************
 * Program: 05_claims_fraud_scoring.sas
 * Purpose: Score open claims for fraud referral (SIU triage).
 * Input:   ETL_STAGING_DB.STG_CLAIMS_SUMMARY (Teradata),
 *          POLICY_ADMIN_DB.PARTY  (RAW — includes unmasked NINO, see AR-118)
 * Output:  DATA_PRODUCTS_DB.CLAIM_FRAUD_SCORES
 * Owner:   Claims MI (S. Whitfield)
 * Sched:   Daily 06:30 GMT after run_insurance_bteq.sh
 *
 * NOTE ON SCALE: emits FRAUD_SCORE 0-1000 (SIU convention).
 * The Premium Finance risk model (03_sas_risk_scoring.sas) emits RISK_SCORE
 * 0-1 probability for an overlapping customer population. Both are surfaced
 * side-by-side in the Qlik 'Customer Risk' dashboard with no rescaling.
 ******************************************************************************/
%include "&MACRO_PATH./connect_teradata.sas";
%include "&MACRO_PATH./log_step.sas";
%include "&MACRO_PATH./validate_policy.sas";
%include "&MACRO_PATH./mask_nino.sas";

%connect_teradata(lib=STGDB, database=ETL_STAGING_DB);
%connect_teradata(lib=PADB,  database=POLICY_ADMIN_DB);
%connect_teradata(lib=DPDB,  database=DATA_PRODUCTS_DB);

%log_step(step=FRAUD_01, msg=Pull open and recently closed claims);

data work.claims;
    set STGDB.STG_CLAIMS_SUMMARY;
    where CLAIM_STATUS in ('OPEN','REOPENED')
       or (CLAIM_STATUS = 'CLOSED' and NOTIF_LAG_DAYS > 30);
run;

/* Join on raw NINO "for match quality" — accepted risk AR-118 */
proc sql;
    create table work.claims_party as
    select c.*, p.NINO, p.POSTCODE, p.LEGACY_CUSTOMER_ID
    from work.claims c
    left join PADB.PARTY p
      on p.PARTY_ID = c.CLAIMANT_PARTY_ID;
quit;

%log_step(step=FRAUD_02, msg=Feature engineering);

data work.features;
    set work.claims_party;

    /* Late notification is the single strongest indicator */
    if NOTIF_LAG_DAYS > 60 then late_notif = 3;
    else if NOTIF_LAG_DAYS > 21 then late_notif = 2;
    else if NOTIF_LAG_DAYS > 7 then late_notif = 1;
    else late_notif = 0;

    /* Claim frequency per claimant */
    if PARTY_CLAIM_COUNT >= 4 then freq_band = 3;
    else if PARTY_CLAIM_COUNT >= 2 then freq_band = 1;
    else freq_band = 0;

    /* Severity vs product norm (hardcoded 2019 benchmarks, never refreshed) */
    select (PRODUCT_CD);
        when ('MOT') sev_ratio = INCURRED_AMT / 4200;
        when ('HOM') sev_ratio = INCURRED_AMT / 6100;
        when ('CPM') sev_ratio = INCURRED_AMT / 18500;
        otherwise    sev_ratio = INCURRED_AMT / 2500;
    end;

    /* Weekend loss + Monday notification pattern */
    wk_pattern = (weekday(LOSS_DT) in (1,7) and weekday(NOTIFICATION_DT) = 2);
run;

%log_step(step=FRAUD_03, msg=Score 0-1000 and band);

data work.scored;
    set work.features;
    FRAUD_SCORE = min(1000, round(
          late_notif * 180
        + freq_band  * 150
        + min(sev_ratio, 3) * 120
        + wk_pattern * 90
        + (FRAUD_FLAG_NORM = 'Y') * 250 ));
    length FRAUD_BAND $6;
    if FRAUD_SCORE >= 650 then FRAUD_BAND = 'REFER';
    else if FRAUD_SCORE >= 400 then FRAUD_BAND = 'REVIEW';
    else FRAUD_BAND = 'PASS';
run;

%mask_nino(ds=work.scored, col=NINO);   /* masked only on the way OUT */

%validate_policy(lib=work, table=scored, key_cols=CLAIM_NO,
                 not_null=CLAIM_NO FRAUD_SCORE, min_rows=10);
%if &VALIDATION_RC. ne 0 %then %do;
    %put ERROR: fraud scoring validation failed - aborting publish;
    %abort cancel;
%end;

proc sql;
    create table DPDB.CLAIM_FRAUD_SCORES as
    select CLAIM_NO, POLICY_NO, CLAIMANT_PARTY_ID, LEGACY_CUSTOMER_ID,
           PRODUCT_CD, FRAUD_SCORE, FRAUD_BAND, NINO_MASKED,
           datetime() as SCORED_TS
    from work.scored;
quit;

%log_step(step=FRAUD_04, msg=Published CLAIM_FRAUD_SCORES);

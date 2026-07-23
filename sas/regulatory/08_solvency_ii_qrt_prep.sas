/*******************************************************************************
 * Program: 08_solvency_ii_qrt_prep.sas
 * Purpose: Assemble S.05.01 (premiums/claims/expenses by LoB) and S.19.01
 *          (claims development) inputs for the QRT submission pack.
 * Input:   ETL_STAGING_DB.STG_EARNED_PREMIUM  (Finance 1/12ths basis!)
 *          ACTUARIAL_DB.IBNR_SUMMARY          (365ths-derived ultimates!)
 * Output:  REGULATORY_DB.QRT_S0501_INPUT, QRT_S1901_INPUT
 * WARNING: The two inputs use different earned-premium conventions. The
 *          combined-ratio in S.05.01 therefore never ties to the Board pack.
 *          Workaround: manual 'true-up' journal in the submission workbook.
 * Mapping: Albion PRODUCT_CD -> Solvency II LoB is duplicated here AND in
 *          Informatica wf_REINSURANCE_BORDEREAUX (LKP_SII_LOB). They drifted
 *          in 2023 (PET mapped to 'Misc financial loss' here, 'Other motor'
 *          there — the latter is simply wrong).
 ******************************************************************************/
%include "&MACRO_PATH./connect_teradata.sas";
%include "&MACRO_PATH./log_step.sas";

%connect_teradata(lib=STGDB, database=ETL_STAGING_DB);
%connect_teradata(lib=ACTDB, database=ACTUARIAL_DB);
%connect_teradata(lib=REGDB, database=REGULATORY_DB);

proc format;
    value $sii_lob
        'MOT' = 'Motor vehicle liability'
        'HOM' = 'Fire and other damage to property'
        'PET' = 'Miscellaneous financial loss'
        'TRV' = 'Assistance'
        'CPM' = 'Fire and other damage to property'
        'CLB' = 'General liability';
run;

proc sql;
    create table REGDB.QRT_S0501_INPUT as
    select put(PRODUCT_CD, $sii_lob.)  as SII_LINE_OF_BUSINESS,
           sum(GWP)                    as GROSS_WRITTEN_PREMIUM,
           sum(EARNED_PREMIUM)         as GROSS_EARNED_PREMIUM,
           sum(CEDED_PREMIUM)          as REINSURERS_SHARE,
           max(AS_AT_DT)               as REPORTING_DT
    from STGDB.STG_EARNED_PREMIUM
    group by 1;
quit;

proc sql;
    create table REGDB.QRT_S1901_INPUT as
    select put(PRODUCT_CD, $sii_lob.)  as SII_LINE_OF_BUSINESS,
           ACCIDENT_YEAR,
           sum(REPORTED_INCURRED)      as GROSS_REPORTED,
           sum(ULTIMATE)               as GROSS_ULTIMATE,
           sum(IBNR)                   as GROSS_IBNR
    from ACTDB.IBNR_SUMMARY
    group by 1, 2;
quit;

%log_step(step=QRT_01, msg=S.05.01 and S.19.01 inputs staged);

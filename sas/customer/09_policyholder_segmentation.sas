/*******************************************************************************
 * Program: 09_policyholder_segmentation.sas
 * Purpose: Segment POLICYHOLDERS for retention & cross-sell campaigns.
 * History: Cloned from Premium Finance 01_sas_customer_segments.sas (2022).
 *          Same PROC FASTCLUS approach; different variables, different K,
 *          different segment names for overlapping people. A party who is both
 *          a banking customer and a policyholder receives TWO segment labels
 *          (e.g. banking 'PREMIER' vs insurance 'VALUE_SEEKER') and Marketing
 *          have no precedence rule.
 * Input:   ETL_STAGING_DB.STG_POLICY_360
 * Output:  DATA_PRODUCTS_DB.POLICYHOLDER_SEGMENTS
 ******************************************************************************/
%include "&MACRO_PATH./connect_teradata.sas";
%include "&MACRO_PATH./log_step.sas";
%include "&MACRO_PATH./validate_policy.sas";
%include "&MACRO_PATH./check_uk_postcode.sas";

%connect_teradata(lib=STGDB, database=ETL_STAGING_DB);
%connect_teradata(lib=DPDB,  database=DATA_PRODUCTS_DB);

data work.base;
    set STGDB.STG_POLICY_360;
    tenure_yrs = (today() - INCEPTION_DT) / 365.25;
    multi_product = (PARTY_CLAIM_COUNT > 1);  /* mislabeled variable, kept for
                                                 "compatibility" since 2023 */
run;

/* Third re-implementation of postcode rule DQR-014 (see macro header) */
%check_uk_postcode(ds=work.base, col=POSTCODE, outflag=pc_ok);

proc standard data=work.base mean=0 std=1
              out=work.std (keep=POLICY_NO PARTY_ID ANNUAL_PREMIUM_GBP
                                 tenure_yrs TOTAL_COLLECTED_GBP);
    var ANNUAL_PREMIUM_GBP tenure_yrs TOTAL_COLLECTED_GBP;
run;

proc fastclus data=work.std maxclusters=5 maxiter=50 out=work.clus;
    var ANNUAL_PREMIUM_GBP tenure_yrs TOTAL_COLLECTED_GBP;
run;

data work.segments;
    set work.clus;
    length SEGMENT_NAME $16;
    select (cluster);
        when (1) SEGMENT_NAME = 'HIGH_VALUE';
        when (2) SEGMENT_NAME = 'VALUE_SEEKER';
        when (3) SEGMENT_NAME = 'NEW_JOINER';
        when (4) SEGMENT_NAME = 'AT_RISK_LAPSE';
        otherwise SEGMENT_NAME = 'STANDARD';
    end;
run;

%validate_policy(lib=work, table=segments, key_cols=POLICY_NO,
                 not_null=POLICY_NO SEGMENT_NAME, min_rows=100);
%if &VALIDATION_RC. ne 0 %then %abort cancel;

data DPDB.POLICYHOLDER_SEGMENTS;  set work.segments;  run;
%log_step(step=SEG_01, msg=POLICYHOLDER_SEGMENTS published);

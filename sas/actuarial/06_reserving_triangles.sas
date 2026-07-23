/*******************************************************************************
 * Program: 06_reserving_triangles.sas
 * Purpose: Build incurred development triangles by product / accident year and
 *          project ultimates via volume-weighted chain ladder.
 * Input:   ALB.ACT.PLCYMSTR.COPY flat file (the SEPARATE actuarial mainframe
 *          feed, CR-2014-311 — bypasses all DWH DQ gates) + CLAIMS_DB.CLAIM.
 * Output:  ACTUARIAL_DB.RESERVE_TRIANGLES, RESERVE_ULTIMATES
 * Owner:   Group Actuarial (R. Osei)
 *
 * EARNED PREMIUM: 365ths daily pro-rata (actuarial convention). Finance BTEQ
 * (06_stg_earned_premium) uses monthly 1/12ths; Informatica recon uses 1/24ths.
 ******************************************************************************/
%include "&MACRO_PATH./connect_teradata.sas";
%include "&MACRO_PATH./log_step.sas";
%include "&MACRO_PATH./julian_to_date.sas";

filename plcy "/interface/actuarial/PLCYMSTR_COPY.dat";

data work.policies_act;
    infile plcy lrecl=80 truncover;
    input @1  POLICY_NO_RAW  $18.
          @19 CLIENT_NO      10.
          @29 PRODUCT_CD     $4.
          @33 INCEPT_JUL     $5.
          @38 ANNL_PREM_PENCE 11.
          @49 POLICY_STATUS  $2.;
    %julian_to_date(injul=INCEPT_JUL, outdt=INCEPTION_DT);
    ANNUAL_PREMIUM_GBP = ANNL_PREM_PENCE / 100;

    /* 365ths earning */
    days_on_risk = min(365, max(0, today() - INCEPTION_DT));
    EARNED_PREMIUM_365 = ANNUAL_PREMIUM_GBP * days_on_risk / 365;
run;

%connect_teradata(lib=CLMDB, database=CLAIMS_DB);
%connect_teradata(lib=ACTDB, database=ACTUARIAL_DB);

%log_step(step=RES_01, msg=Build accident-year x development-year triangle);

proc sql;
    create table work.claims_dev as
    select substr(c.POLICY_NO,5,3)                        as PRODUCT_CD,
           /* LOSS_DT is DD/MM/YYYY text */
           input(c.LOSS_DT, ddmmyy10.)                    as LOSS_DATE format=date9.,
           year(calculated LOSS_DATE)                     as ACCIDENT_YEAR,
           intck('year', calculated LOSS_DATE, today())   as DEV_YEAR,
           c.INCURRED_AMT
    from CLMDB.CLAIM c
    where c.CLAIM_STATUS ne 'DECLINED';
quit;

proc summary data=work.claims_dev nway;
    class PRODUCT_CD ACCIDENT_YEAR DEV_YEAR;
    var INCURRED_AMT;
    output out=work.tri (drop=_type_ _freq_) sum=INCURRED_CUM;
run;

%log_step(step=RES_02, msg=Volume-weighted chain ladder factors);

proc sql;
    create table work.ldf as
    select a.PRODUCT_CD, a.DEV_YEAR,
           sum(b.INCURRED_CUM) / sum(a.INCURRED_CUM) as LDF
    from work.tri a
    join work.tri b
      on b.PRODUCT_CD = a.PRODUCT_CD
     and b.ACCIDENT_YEAR = a.ACCIDENT_YEAR
     and b.DEV_YEAR = a.DEV_YEAR + 1
    group by a.PRODUCT_CD, a.DEV_YEAR;
quit;

data ACTDB.RESERVE_TRIANGLES;  set work.tri;  run;
data ACTDB.RESERVE_LDF;        set work.ldf;  run;

%log_step(step=RES_03, msg=Triangles + LDFs published to ACTUARIAL_DB);

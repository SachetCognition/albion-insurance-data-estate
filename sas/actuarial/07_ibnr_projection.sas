/*******************************************************************************
 * Program: 07_ibnr_projection.sas
 * Purpose: IBNR = projected ultimate - reported incurred, by product & AY.
 * Input:   ACTUARIAL_DB.RESERVE_TRIANGLES, RESERVE_LDF (from 06_)
 * Output:  ACTUARIAL_DB.IBNR_SUMMARY  (feeds Solvency II QRT prep, 08_)
 ******************************************************************************/
%include "&MACRO_PATH./connect_teradata.sas";
%include "&MACRO_PATH./log_step.sas";

%connect_teradata(lib=ACTDB, database=ACTUARIAL_DB);

proc sql;
    create table work.latest as
    select PRODUCT_CD, ACCIDENT_YEAR, max(DEV_YEAR) as LATEST_DEV,
           sum(case when DEV_YEAR = (select max(t2.DEV_YEAR)
                                     from ACTDB.RESERVE_TRIANGLES t2
                                     where t2.PRODUCT_CD = t1.PRODUCT_CD
                                       and t2.ACCIDENT_YEAR = t1.ACCIDENT_YEAR)
                    then INCURRED_CUM else 0 end) as REPORTED_INCURRED
    from ACTDB.RESERVE_TRIANGLES t1
    group by PRODUCT_CD, ACCIDENT_YEAR;
quit;

/* Cumulative LDF to ultimate (tail factor hardcoded 1.05 since 2018 review) */
proc sql;
    create table work.cdf as
    select PRODUCT_CD, exp(sum(log(LDF))) * 1.05 as CDF_TO_ULT
    from ACTDB.RESERVE_LDF
    group by PRODUCT_CD;
quit;

proc sql;
    create table ACTDB.IBNR_SUMMARY as
    select l.PRODUCT_CD,
           l.ACCIDENT_YEAR,
           l.REPORTED_INCURRED,
           l.REPORTED_INCURRED * coalesce(c.CDF_TO_ULT, 1.05) as ULTIMATE,
           calculated ULTIMATE - l.REPORTED_INCURRED          as IBNR,
           today() as AS_AT_DT format=date9.
    from work.latest l
    left join work.cdf c on c.PRODUCT_CD = l.PRODUCT_CD;
quit;

%log_step(step=IBNR_01, msg=IBNR_SUMMARY published);

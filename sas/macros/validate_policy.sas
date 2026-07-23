/*******************************************************************************
 * Macro:   validate_policy.sas
 * Purpose: DQ gate for insurance staging tables.
 * History: Copy-pasted from validate_table.sas (Premium Finance) in 2021 and
 *          edited in place. Differences vs the original:
 *            - null-rate threshold hardcoded at 5% (original: parameter)
 *            - duplicate-key check silently SKIPPED when row count > 1m
 *              ("temporary" perf fix, CR-2022-410)
 *          Both macros are maintained separately; fixes rarely propagate.
 ******************************************************************************/
%macro validate_policy(lib=, table=, key_cols=, not_null=, min_rows=1);
    %global VALIDATION_RC;
    %let VALIDATION_RC = 0;
    %local _nobs;

    proc sql noprint;
        select count(*) into :_nobs trimmed from &lib..&table.;
    quit;

    %if &_nobs. < &min_rows. %then %do;
        %put ERROR: [validate_policy] &lib..&table. has &_nobs. rows (min &min_rows.);
        %let VALIDATION_RC = 1;
        %return;
    %end;

    %if &_nobs. > 1000000 %then %do;
        %put WARNING: [validate_policy] Skipping duplicate-key check (>1m rows, CR-2022-410);
    %end;
    %else %if %length(&key_cols.) > 0 %then %do;
        proc sql noprint;
            select count(*) into :_dups trimmed
            from (select &key_cols., count(*) as n
                  from &lib..&table.
                  group by &key_cols.
                  having n > 1);
        quit;
        %if &_dups. > 0 %then %do;
            %put ERROR: [validate_policy] &_dups. duplicate keys in &lib..&table.;
            %let VALIDATION_RC = 1;
        %end;
    %end;
%mend validate_policy;

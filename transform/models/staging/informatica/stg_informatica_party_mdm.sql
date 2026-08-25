-- Port of informatica/XML/wf_PARTY_MDM_SYNC.xml (mapping m_PARTY_MDM_SYNC).
-- One CTE per PowerCenter transformation instance:
--   EXP_EMAIL_DQ     DQR-007 variant B: lower + trim, then full-ish email regex
--   EXP_NINO_MASK    DQR-021 masking (first 2 + last 2 characters retained)
--   EXP_XMATCH_APF   name/DOB cross-match to the APF banking customer book
--   (survivorship)   most-recent-update wins, EXCEPT email where the longest
--                    string wins (undocumented 2020 decision, kept + labelled)
--
-- Identity: the canonical key comes from the shared party_canonical_key macro
-- (precedence PARTY > LEGACY > APF > LIFE400 > MKTG > NINO), so match-rate
-- movements vs the legacy ~55% stay attributable. Six schemes are in scope;
-- this sample carries PARTY / LEGACY / APF / NINO values, while LIFE400
-- (CLIENT_NO) and MKTG (MKTG_CUST_ID) have no source column in the sample and
-- are passed to the macro as nulls.
with parties as (
    select
        party_id,
        party_type,
        first_name,
        last_name,
        birth_dt as birth_dt_txt,
        nino,
        email_addr,
        postcode,
        legacy_customer_id,
        mdm_golden_flag,
        create_dt
    from {{ ref('raw_parties') }}
),

exp_email_dq as (
    select
        p.*,
        lower(trim(p.email_addr)) as email_std,
        case
            when {{ regexp_full_match(
                'lower(trim(p.email_addr))',
                '[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}'
            ) }} then 'VALID'
            else 'INVALID'
        end as email_dq_status
    from parties as p
),

exp_nino_mask as (
    select
        e.*,
        case
            when e.nino is null or length(trim(e.nino)) < 9 then null
            else substr(upper(trim(e.nino)), 1, 2) || '*****' || substr(upper(trim(e.nino)), 8, 2)
        end as nino_masked
    from exp_email_dq as e
),

exp_xmatch_apf as (
    select
        n.*,
        -- PARTY.BIRTH_DT is DD/MM/YYYY *text*; APF CUSTOMERS.DATE_OF_BIRTH is a
        -- date. Converted by substring rather than a TO_DATE format mask so the
        -- expression renders identically on DuckDB and Snowflake.
        cast(
            substr(n.birth_dt_txt, 7, 4) || '-' || substr(n.birth_dt_txt, 4, 2)
            || '-' || substr(n.birth_dt_txt, 1, 2) as date
        ) as birth_dt,
        -- Legacy used SOUNDEX(surname); DuckDB has no SOUNDEX, so the blocking
        -- key is the upper-cased 4-character surname prefix. Documented
        -- intentional change: it keeps the match rate identical on both engines.
        upper(substr(trim(n.last_name), 1, 4)) as surname_block_key
    from exp_nino_mask as n
),

apf_customers as (
    select
        customer_id,
        upper(trim(last_name)) as last_name_std,
        upper(substr(trim(last_name), 1, 4)) as surname_block_key,
        lower(trim(email)) as email_std,
        date_of_birth
    from {{ ref('raw_customers') }}
),

lkp_apf_by_email as (
    select
        email_std,
        min(customer_id) as customer_id
    from apf_customers
    where email_std is not null
    group by email_std
),

lkp_apf_by_name_dob as (
    select
        surname_block_key,
        date_of_birth,
        min(customer_id) as customer_id
    from apf_customers
    group by surname_block_key, date_of_birth
),

crosswalked as (
    select
        x.*,
        lkp_legacy.customer_id as legacy_xref_customer_id,
        lkp_email.customer_id as apf_email_customer_id,
        lkp_name.customer_id as apf_name_dob_customer_id
    from exp_xmatch_apf as x
    left join apf_customers as lkp_legacy
        on x.legacy_customer_id = lkp_legacy.customer_id
    left join lkp_apf_by_email as lkp_email
        on x.email_std = lkp_email.email_std
    left join lkp_apf_by_name_dob as lkp_name
        on
            x.surname_block_key = lkp_name.surname_block_key
            and x.birth_dt = lkp_name.date_of_birth
),

matched as (
    select
        c.*,
        coalesce(
            c.legacy_xref_customer_id, c.apf_email_customer_id, c.apf_name_dob_customer_id
        ) as apf_customer_id,
        case
            when c.legacy_xref_customer_id is not null then 'LEGACY_XREF'
            when c.apf_email_customer_id is not null then 'APF_EMAIL'
            when c.apf_name_dob_customer_id is not null then 'APF_NAME_DOB'
            else 'UNMATCHED'
        end as match_method,
        -- a legacy link independently reproduced by a converged rule
        case
            when
                c.legacy_xref_customer_id is not null
                and (
                    c.legacy_xref_customer_id = c.apf_email_customer_id
                    or c.legacy_xref_customer_id = c.apf_name_dob_customer_id
                )
                then 'Y'
            else 'N'
        end as match_corroborated_flag
    from crosswalked as c
),

clustered as (
    select
        m.*,
        -- duplicate-candidate cluster: NINO exact where present, else the
        -- surname-block + DOB pair used by the legacy fuzzy match
        coalesce(
            'NINO:' || nullif(upper(trim(m.nino)), ''),
            'NAMEDOB:' || m.surname_block_key || '|' || cast(m.birth_dt as varchar)
        ) as mdm_cluster_key
    from matched as m
),

survivorship as (
    select
        mdm_cluster_key,
        max(create_dt) as cluster_latest_create_dt,
        -- email survivorship: longest standardised string wins (legacy rule)
        max(length(email_std)) as cluster_max_email_len,
        count(*) as cluster_size
    from clustered
    group by mdm_cluster_key
),

survivor_email as (
    select
        c.mdm_cluster_key,
        min(c.email_std) as survivor_email_std
    from clustered as c
    inner join survivorship as s
        on
            c.mdm_cluster_key = s.mdm_cluster_key
            and length(c.email_std) = s.cluster_max_email_len
    group by c.mdm_cluster_key
)

select
    c.party_id,
    {{ party_canonical_key(
        party_id='c.party_id',
        legacy_customer_id='c.legacy_customer_id',
        customer_id='c.apf_customer_id',
        nino='c.nino'
    ) }} as party_canonical_key,
    c.party_type,
    c.first_name,
    c.last_name,
    c.birth_dt,
    c.email_std,
    c.email_dq_status,
    c.nino_masked,
    {{ standardise_postcode('c.postcode') }} as postcode_std,
    case
        when {{ is_valid_uk_postcode('c.postcode') }} then 'VALID' else 'INVALID'
    end as postcode_dq_status,
    c.legacy_customer_id,
    c.apf_customer_id,
    c.match_method,
    c.match_corroborated_flag,
    c.mdm_golden_flag,
    c.mdm_cluster_key,
    s.cluster_size,
    se.survivor_email_std,
    -- most-recent-update wins for the cluster survivor; ties broken on party_id
    case
        when c.create_dt = s.cluster_latest_create_dt then 'Y' else 'N'
    end as cluster_survivor_candidate_flag,
    case when c.match_method = 'UNMATCHED' then 'Y' else 'N' end as mdm_suspect_queue_flag,
    c.create_dt,
    current_timestamp as load_ts
from clustered as c
inner join survivorship as s
    on c.mdm_cluster_key = s.mdm_cluster_key
left join survivor_email as se
    on c.mdm_cluster_key = se.mdm_cluster_key

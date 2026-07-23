-- Domain: canonical PARTY dimension.
-- Unifies the SIX identity schemes into ONE surrogate party key with
-- source-system lineage columns, closing the identity fragmentation documented
-- in README.md finding #1 and DQR-041:
--   1. PARTY_ID       (POLARIS)            -> master spine
--   2. CUSTOMER_ID    (APF banking)        -> via PARTY.LEGACY_CUSTOMER_ID
--   3. CLIENT_NO      (LEGACY_PAS/mainframe)-> via REF_DB.XREF_CLIENT_PARTY
--   4. customer_ref   (SOAP, mixed scheme) -> resolved downstream in the API, not a store
--   5. LIFE_POLICY_ID (LIFE400)            -> via fuzzy name+DOB match (matched_party_id)
--   6. MKTG_CUST_ID   (partner loyalty)    -> never crosswalked; tracked as a gap
--
-- Replaces the MDM survivorship in Informatica wf_PARTY_MDM_SYNC (~55% match).
-- NINO is MASKED here (DQR-021); no unmasked NINO leaves the domain layer,
-- closing the AR-118 raw-join bypass. NINO_RAW from staging is deliberately
-- NOT selected.

with party as (
    select * from {{ ref('stg_party') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

xref as (
    -- collapse the manual crosswalk to one CLIENT_NO per PARTY_ID (highest confidence)
    select party_id, client_no, match_method, match_confidence
    from (
        select
            party_id,
            client_no,
            match_method,
            match_confidence,
            row_number() over (
                partition by party_id order by match_confidence desc nulls last
            ) as rn
        from xref
    )
    where rn = 1
),

life as (
    select * from {{ ref('stg_life_policy') }}
),

-- POLARIS-anchored parties (schemes 1/2/3 resolve onto this spine).
polaris as (
    select
        md5(p.party_id)                               as party_key,
        p.party_id                                    as polaris_party_id,
        x.client_no                                   as legacy_client_no,
        p.legacy_customer_id                          as apf_customer_id,
        cast(null as varchar)                         as life_policy_id,
        cast(null as varchar)                         as mktg_cust_id,
        p.party_type,
        p.first_name,
        p.last_name,
        p.birth_dt,
        {{ mask_nino('p.nino_raw') }}                 as nino_masked,
        coalesce(p.email, c.email)                    as email,
        p.phone,
        p.addr_line1,
        p.city,
        p.postcode,
        p.mdm_golden_flag,
        p.create_dt,
        'POLARIS'                                     as primary_source_system,
        array_construct_compact(
            'POLARIS',
            case when x.client_no is not null then 'LEGACY_PAS' end,
            case when p.legacy_customer_id is not null then 'APF_BANKING' end
        )                                             as source_systems,
        x.match_method                                as party_match_method,
        x.match_confidence                            as party_match_confidence
    from party p
    left join xref x on x.party_id = p.party_id
    left join customers c on c.customer_id = p.legacy_customer_id
),

-- LIFE400 policyholders whose fuzzy name+DOB match found NO group party get
-- their own standalone party record keyed on LIFE_POLICY_ID (keyless book).
-- LIFE400 has no postcode field (5th DQR-014 variant): postcode is null.
life_unmatched as (
    select
        md5('LIFE400:' || l.life_policy_id)           as party_key,
        cast(null as varchar)                         as polaris_party_id,
        cast(null as number)                          as legacy_client_no,
        cast(null as number)                          as apf_customer_id,
        l.life_policy_id                              as life_policy_id,
        cast(null as varchar)                         as mktg_cust_id,
        'PERSON'                                      as party_type,
        cast(null as varchar)                         as first_name,
        l.insured_name                                as last_name,
        l.insured_dob                                 as birth_dt,
        cast(null as varchar)                         as nino_masked,
        cast(null as varchar)                         as email,
        cast(null as varchar)                         as phone,
        cast(null as varchar)                         as addr_line1,
        cast(null as varchar)                         as city,
        cast(null as varchar)                         as postcode,
        cast(null as varchar)                         as mdm_golden_flag,
        cast(null as date)                            as create_dt,
        'LIFE400'                                     as primary_source_system,
        array_construct('LIFE400')                    as source_systems,
        'NAME_DOB_FUZZY'                              as party_match_method,
        cast(null as number)                          as party_match_confidence
    from life l
    where l.matched_party_id is null
)

select * from polaris
union all
select * from life_unmatched

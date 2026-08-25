/*
    Party-resolution backfill for the keyless life book (LOST-SOURCE
    reconstruction, part of DataStage LIFE_POLICY_LOAD).

    FD-010 carries no customer or party identifier at all: the legacy job
    matched INSNAME + INSDOB to group PARTY records with an in-job fuzzy match
    whose threshold, match rate and suspect queue are all lost. This model
    replaces it with deterministic, auditable tiers and a suspect queue, so
    that every accepted match can be explained and every rejected one is
    visible instead of silently dropped:

      T1_NAME_DOB     upper(INSNAME) = upper(FIRST_NAME || ' ' || LAST_NAME)
                      AND DOB equal, exactly one candidate  -> auto-accept
      T2_SURNAME_DOB  surname + DOB equal, exactly one candidate
                      -> auto-accept
      T3_CLIENT_NO    surname resolves to exactly one LEGACY_PAS CLIENT_NO on
                      feed FD-001 (PLCYMSTR) -> auto-accept
      SUSPECT_*       candidates exist but are ambiguous -> manual queue
      NO_CANDIDATE    no candidate at all

    The canonical key is always derived with the shared party_canonical_key
    macro (precedence PARTY > LEGACY > APF > LIFE400 > MKTG > NINO) so that
    the life book's match rate stays comparable with the other workstreams.

    On the feeds available today every surname hit is ambiguous, so no match
    auto-accepts and the whole book lands in the suspect queue / no-candidate
    tiers - a quantified statement of the gap, not a silent 0%. The AS/400
    CLNTMST client master was never extracted; if it is ever recovered it
    plugs in as a T0 tier ahead of T1.
*/

with life as (

    select
        life_policy_id,
        insured_name,
        insured_dob_yymmdd,
        insured_dob_str,
        upper(trim(insured_name)) as insured_name_norm
    from {{ ref('stg_life_policy_landing') }}

),

life_keys as (

    select
        life.*,
        -- surname = last whitespace-delimited token of the single INSNAME field
        reverse(split_part(reverse(life.insured_name_norm), ' ', 1)) as insured_surname,
        cast(
            cast(extract(
                year from {{ julian_to_date("substr(life.insured_dob_str, 1, 2) || '001'") }}
            ) as bigint) * 10000
            + cast(substr(life.insured_dob_str, 3, 4) as bigint)
            as bigint
        ) as insured_dob_ccyymmdd
    from life

),

parties as (

    select
        party_id,
        legacy_customer_id,
        nino,
        upper(trim(first_name)) as first_name_norm,
        upper(trim(last_name)) as last_name_norm,
        upper(trim(first_name)) || ' ' || upper(trim(last_name)) as full_name_norm,
        case
            when length(trim(birth_dt)) = 10
                then cast(
                    substr(trim(birth_dt), 7, 4) || substr(trim(birth_dt), 4, 2) || substr(trim(birth_dt), 1, 2)
                    as bigint
                )
        end as birth_ccyymmdd
    from {{ ref('raw_parties') }}
    where upper(trim(party_type)) = 'PERSON'

),

plcymstr as (

    select
        client_no,
        surname,
        upper(trim(surname)) as surname_norm
    from {{ ref('stg_life_plcymstr_client') }}

),

name_dob_candidates as (

    select
        l.life_policy_id,
        count(*) as candidate_count,
        min(p.party_id) as candidate_party_id,
        min(p.legacy_customer_id) as candidate_legacy_customer_id,
        min(p.nino) as candidate_nino
    from life_keys as l
    inner join parties as p
        on
            l.insured_name_norm = p.full_name_norm
            and l.insured_dob_ccyymmdd = p.birth_ccyymmdd
    group by l.life_policy_id

),

surname_dob_candidates as (

    select
        l.life_policy_id,
        count(*) as candidate_count,
        min(p.party_id) as candidate_party_id,
        min(p.legacy_customer_id) as candidate_legacy_customer_id,
        min(p.nino) as candidate_nino
    from life_keys as l
    inner join parties as p
        on
            l.insured_surname = p.last_name_norm
            and l.insured_dob_ccyymmdd = p.birth_ccyymmdd
    group by l.life_policy_id

),

client_no_candidates as (

    select
        l.life_policy_id,
        count(distinct m.client_no) as candidate_count,
        min(m.client_no) as candidate_client_no
    from life_keys as l
    inner join plcymstr as m
        on l.insured_surname = m.surname_norm
    group by l.life_policy_id

),

assembled as (

    select
        l.life_policy_id,
        l.insured_name,
        l.insured_surname,
        l.insured_dob_ccyymmdd,
        coalesce(nd.candidate_count, 0) as name_dob_candidate_count,
        coalesce(sd.candidate_count, 0) as surname_dob_candidate_count,
        coalesce(cn.candidate_count, 0) as client_no_candidate_count,
        case
            when nd.candidate_count = 1 then 'T1_NAME_DOB'
            when sd.candidate_count = 1 then 'T2_SURNAME_DOB'
            when cn.candidate_count = 1 then 'T3_CLIENT_NO'
            when nd.candidate_count > 1 then 'SUSPECT_NAME_DOB_AMBIGUOUS'
            when sd.candidate_count > 1 then 'SUSPECT_SURNAME_DOB_AMBIGUOUS'
            when cn.candidate_count > 1 then 'SUSPECT_CLIENT_NO_AMBIGUOUS'
            else 'NO_CANDIDATE'
        end as match_tier,
        case
            when nd.candidate_count = 1 then nd.candidate_party_id
            when sd.candidate_count = 1 then sd.candidate_party_id
        end as matched_party_id,
        case
            when nd.candidate_count = 1 then nd.candidate_legacy_customer_id
            when sd.candidate_count = 1 then sd.candidate_legacy_customer_id
        end as matched_legacy_customer_id,
        case
            when nd.candidate_count = 1 then nd.candidate_nino
            when sd.candidate_count = 1 then sd.candidate_nino
        end as matched_nino,
        case when cn.candidate_count = 1 then cn.candidate_client_no end as matched_client_no
    from life_keys as l
    left join name_dob_candidates as nd
        on l.life_policy_id = nd.life_policy_id
    left join surname_dob_candidates as sd
        on l.life_policy_id = sd.life_policy_id
    left join client_no_candidates as cn
        on l.life_policy_id = cn.life_policy_id

)

select
    life_policy_id,
    insured_name,
    insured_surname,
    insured_dob_ccyymmdd,
    match_tier,
    matched_party_id,
    matched_legacy_customer_id,
    matched_client_no,
    name_dob_candidate_count,
    surname_dob_candidate_count,
    client_no_candidate_count,
    {{ party_canonical_key(
        party_id='matched_party_id',
        legacy_customer_id='matched_legacy_customer_id',
        client_no='matched_client_no',
        nino='matched_nino'
    ) }} as party_canonical_key,
    match_tier in ('T1_NAME_DOB', 'T2_SURNAME_DOB', 'T3_CLIENT_NO') as is_auto_accepted,
    match_tier like 'SUSPECT%' as is_suspect_queue
from assembled

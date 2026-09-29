/*
    ADDRMST repatriation for the life book.

    HONEST STATEMENT OF SOURCE AVAILABILITY: the AS/400 ADDRMST correspondence
    addresses were descoped from the 2016 integration and never migrated
    (docs/known_issues_register.md; as400_life/extracts/LIFEXTR.clle explicitly
    states "NO ADDRESS/POSTCODE DATA"). No ADDRMST extract exists anywhere in
    this repository, so nothing can be repatriated FROM ADDRMST today.

    What this model does instead is stand up the repatriation target and
    populate it from the best available UK address attribute for the life
    book - the postcode carried on LEGACY_PAS feed FD-001 (PLCYMSTR) for the
    surname candidates found by stg_life_party_resolution - with the canonical
    DQR-014 standardisation applied. Every row is labelled with its
    provenance and with whether the underlying party match was auto-accepted,
    so no ambiguous match can leak an address into a golden record:

      address_source = 'PLCYMSTR_FD001_CANDIDATE'   (what we have)
      address_source = 'ADDRMST_AS400'              (reserved; source lost)

    When ADDRMST is finally extracted it becomes a union branch here with
    address_source = 'ADDRMST_AS400' and takes precedence, and the
    is_loadable flag flips on for matches that are auto-accepted.
*/

with resolution as (

    select
        life_policy_id,
        insured_name,
        insured_surname,
        match_tier,
        is_auto_accepted,
        matched_client_no,
        client_no_candidate_count
    from {{ ref('stg_life_party_resolution') }}

),

plcymstr_addresses as (

    select
        client_no,
        upper(trim(surname)) as surname_norm,
        postcode_raw,
        postcode,
        is_valid_postcode
    from {{ ref('stg_life_plcymstr_client') }}
    where postcode_raw is not null and postcode_raw <> ''

),

candidates as (

    select distinct
        r.life_policy_id,
        r.insured_name,
        r.match_tier,
        r.is_auto_accepted,
        a.client_no as source_client_no,
        a.postcode_raw,
        a.postcode,
        a.is_valid_postcode
    from resolution as r
    inner join plcymstr_addresses as a
        on r.insured_surname = a.surname_norm

)

select
    life_policy_id,
    insured_name,
    match_tier,
    source_client_no,
    postcode_raw,
    postcode,
    is_valid_postcode,
    'PLCYMSTR_FD001_CANDIDATE' as address_source,
    count(*) over (partition by life_policy_id) as candidate_address_count,
    is_auto_accepted and is_valid_postcode as is_loadable
from candidates

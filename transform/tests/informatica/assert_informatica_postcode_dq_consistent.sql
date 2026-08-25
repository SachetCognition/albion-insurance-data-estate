-- The converged DQR-014 rule must be applied identically in both Informatica
-- ports: any postcode marked VALID must be in canonical 'OUTWARD INWARD' form,
-- and the two models must never disagree about the same standardised value.
with policy_pc as (
    select distinct
        postcode_std,
        postcode_dq_status
    from {{ ref('stg_informatica_policy_master') }}
    where postcode_std is not null
),

party_pc as (
    select distinct
        postcode_std,
        postcode_dq_status
    from {{ ref('stg_informatica_party_mdm') }}
    where postcode_std is not null
),

disagreements as (
    select
        a.postcode_std,
        a.postcode_dq_status as policy_status,
        b.postcode_dq_status as party_status
    from policy_pc as a
    inner join party_pc as b
        on a.postcode_std = b.postcode_std
    where a.postcode_dq_status <> b.postcode_dq_status
),

malformed_valid as (
    select
        postcode_std,
        postcode_dq_status as policy_status,
        postcode_dq_status as party_status
    from party_pc
    where
        postcode_dq_status = 'VALID'
        and (
            postcode_std like '%  %'
            or postcode_std <> upper(postcode_std)
            or length(postcode_std) - length(replace(postcode_std, ' ', '')) <> 1
        )
)

select * from disagreements
union all
select * from malformed_valid

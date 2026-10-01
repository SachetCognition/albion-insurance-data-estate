-- Staging: CLAIMS_DB.CLAIM (Guidewire CC + LEGACY_CLM union).
-- Canonical normalisations applied ONCE here:
--   * LOSS_DT DD/MM/YYYY text -> DATE using the UK interpretation (replaces the
--     DD/MM vs MM/DD split-brain: Informatica wf_CLAIMS_FNOL_INTRADAY parses
--     Guidewire as MM/DD/YYYY per INC0067812; BTEQ 05_stg_claims_summary uses
--     DD/MM/YYYY). We standardise on DD/MM/YYYY.
--   * FRAUD_FLAG 'S' harmonised with ONE mapping (replaces the opposite mappings
--     in Informatica EXP_CLAIM_FLAGS 'S'->'N' vs BTEQ 'S'->'Y'). Canonical:
--     suspected ('S') is a positive fraud signal for SIU triage -> 'Y'.
--   * POLICY_NO normalised to the canonical form.
with src as (
    select * from {{ source('raw', 'claim') }}
)
select
    claim_no,
    {{ normalise_policy_no('policy_no') }}            as policy_no,
    claimant_party_id,
    {{ parse_ddmmyyyy_text('loss_dt') }}              as loss_dt,
    try_to_date(to_varchar(notification_dt))          as notification_dt,
    cause_cd,
    upper(trim(claim_status))                         as claim_status,
    try_to_decimal(to_varchar(incurred_amt), 12, 2)   as incurred_amt,
    try_to_decimal(to_varchar(paid_amt), 12, 2)       as paid_amt,
    try_to_decimal(to_varchar(outstanding_reserve), 12, 2) as outstanding_reserve,
    upper(trim(coalesce(fraud_flag, '')))             as fraud_flag_raw,
    case
        when upper(trim(coalesce(fraud_flag, ''))) in ('Y', 'S') then 'Y'
        else 'N'
    end                                               as fraud_flag,
    handler_id,
    upper(trim(source_system))                        as source_system
from src

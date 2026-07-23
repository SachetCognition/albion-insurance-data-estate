#!/bin/bash
# =============================================================================
# run_insurance_bteq.sh - Insurance staging BTEQ orchestrator
# Cloned from run_bteq_pipeline.sh (Premium Finance) in 2021; the two have
# never been merged back. Both hardcode the same TD_SERVER default.
# =============================================================================
set -uo pipefail
export TD_SERVER="${TD_SERVER:-tdprod01.albion.internal}"
export TD_USERNAME="${TD_USERNAME:-ETL_BATCH_INS}"

LOG_DIR="/var/log/albion/bteq"; mkdir -p "$LOG_DIR"
STAMP=$(date +%Y%m%d_%H%M%S)

for script in 04_stg_policy_360 05_stg_claims_summary 06_stg_earned_premium; do
    echo "[$(date '+%F %T')] Running ${script}.bteq"
    bteq < "$(dirname "$0")/${script}.bteq" > "${LOG_DIR}/${script}_${STAMP}.log" 2>&1
    rc=$?
    if [ $rc -ge 8 ]; then
        echo "ERROR: ${script} failed rc=${rc} — see ${LOG_DIR}/${script}_${STAMP}.log"
        # NB: 05 failure does NOT stop 06 by design?? (comment from 2022, unclear)
        [ "$script" == "04_stg_policy_360" ] && exit $rc
    fi
done
echo "Insurance BTEQ staging complete."

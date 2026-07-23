#!/bin/bash
# Insurance SAS pipeline orchestrator (cloned 2021 from premium_finance/run_sas_pipeline.sh)
set -uo pipefail
export MACRO_PATH="${MACRO_PATH:-$(dirname "$0")/macros}"
SAS_EXE="${SAS_EXE:-/opt/sas94/SASFoundation/9.4/sas}"
LOG_DIR="/var/log/albion/sas"; mkdir -p "$LOG_DIR"

run_sas () {
    local pgm=$1
    echo "[$(date '+%F %T')] $pgm"
    "$SAS_EXE" -sysin "$pgm" -log "$LOG_DIR/$(basename "$pgm" .sas)_$(date +%Y%m%d).log" -nodms
    local rc=$?
    [ $rc -gt 1 ] && { echo "FATAL rc=$rc in $pgm"; exit $rc; }
}

run_sas "$(dirname "$0")/claims_fraud/05_claims_fraud_scoring.sas"
run_sas "$(dirname "$0")/actuarial/06_reserving_triangles.sas"
run_sas "$(dirname "$0")/actuarial/07_ibnr_projection.sas"
run_sas "$(dirname "$0")/regulatory/08_solvency_ii_qrt_prep.sas"
run_sas "$(dirname "$0")/customer/09_policyholder_segmentation.sas"
echo "Insurance SAS pipeline complete."

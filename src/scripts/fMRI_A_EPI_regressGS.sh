#!/bin/bash
#
# Script: fMRI_A adaptaion from Matlab script 
#
###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

##############################################################################

## PHYSIOLOGICAL REGRESSORS
msg2file " =========================================================="
msg2file "                5.3  GLOBAL SIGNAL REGRESSORS "
msg2file " =========================================================="

fileIN="${EPIrun_out}${configs_EPI_resting_file}"

if  [[ ! -e ${fileIN} ]]; then
    log "ERROR - ${fileIN} not found. Connot perform regressors analysis"
    exit 1
fi 


if [ "${configs_EPI_numGS}" -ne 0 ]; then  #if ${flags_EPI_GS}; then
    log " Global signal regression is ON. ${configs_EPI_numGS} Global signal regressors will be computed "
    compute_gs=${configs_EPI_numGS}
else
    log " Global signal regression is OFF "
    log " Global signal and its derivative will be computed for QC purposes, only"
    compute_gs=2
fi

cmd="python ${EXEDIR}/src/func/gs_regressors.py \
     ${fileIN} ${NuisancePhysReg_out} ${compute_gs}"
log $cmd
eval $cmd

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
    log "ERROR - ${fileIN} not found. Connot perform physiological regressors analysis"
    exit 1
fi 


if ${flags_EPI_GS}; then
    log " Global signal regression is ON "
else
    log " Global signal regression is OFF - will compute global signal for QC"
    export configs_EPI_numGS=2
fi

cmd="python ${EXEDIR}/src/func/gs_regressors.py \
     ${fileIN} ${NuisancePhysReg_out}"
log $cmd
eval $cmd

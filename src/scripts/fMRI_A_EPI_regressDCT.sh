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

msg2file " =========================================================="
msg2file "                5.4 DCT HIGH-PASS REGRESSOR "
msg2file " =========================================================="

fileIN="${EPIrun_out}${configs_EPI_resting_file}"

if  [[ ! -e ${fileIN} ]]; then
    log "ERROR - ${fileIN} not found. Connot perform physiological regressors analysis"
    exit 1
fi


if ${configs_EPI_DCThighpass}; then
    log " DCT bases will be included in regression "
else
    log " DCT bases will NOT be included in regression "
    export configs_EPI_dctfMin=0
fi

cmd="python ${EXEDIR}/src/func/dct_regressors.py \
     ${fileIN} ${NuisancePhysReg_out}"
log $cmd
eval $cmd

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
    log "ERROR - ${fileIN} not found. Connot perform regressor analysis"
    exit 1
fi


cmd="python ${EXEDIR}/src/func/dct_regressors.py \
     ${fileIN} ${NuisancePhysReg_out}"
log $cmd
eval $cmd


if [[ ! -f "${NuisancePhysReg_out}/dataDCT.npz" ]]; then 
    echoerr "DCT regressors were not computed. Exiting" 
    log --no-datetime "configs_EPI_dctfMin should be greater than 0. Recommended value is 0.009"
    exit 1
fi 
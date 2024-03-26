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
msg2file "=========================================================="
msg2file "              5.5 APPLY REGRESSORS "
msg2file "=========================================================="


log "filename postfix for output image -- ${nR}"

if [ "${configs_EPI_numGS}" -ne 0 ]; then   
    log " Global signal regression is ON "
else
    log " Global signal regression is OFF "
fi

if [[ ${flags_EPI_FreqFilt} == "DCT" ]]; then
    log " DCT bases will be included in regression "

elif [[ ${flags_EPI_FreqFilt} == "BPF" ]]; then
    log " Post Regression: Data will be demeaned, detrended, and Bandpass filtered "
fi

cmd="python ${EXEDIR}/src/func/apply_reg.py \
     ${configs_NuisanceReg} ${configs_PhysiolReg}"
log $cmd
eval $cmd

         







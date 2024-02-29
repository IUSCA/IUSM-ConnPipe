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

if ${flags_EPI_GS}; then
    log " Global signal regression is ON "
else
    log " Global signal regression is OFF "
    export configs_EPI_numGS=0
fi

if [[ ${flags_EPI_FreqFilt} == "DCT" ]]; then
    log " DCT bases will be included in regression "


elif [[ ${flags_EPI_FreqFilt} == "BPF" ]]; then
    log " Post Regression: Data will be demeaned, detrended, and Bandpass filtered "
    export configs_EPI_dctfMin=0
fi

cmd="python ${EXEDIR}/src/func/apply_reg.py \
     ${flags_NuisanceReg} ${flags_PhysiolReg}"
log $cmd
eval $cmd

##############################################################################
if [[ ${flags_FreqFilt} == "BPF" ]]; then
    
    cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_Bandpass.sh"
    echo $cmd
    eval $cmd
    exitcode=$?

    if [[ ${exitcode} -ne 0 ]] ; then
        echoerr "problem at fMRI_A_EPI_Bandpass. exiting."
        exit 1
    fi  

fi             







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
msg2file "                5.3 OTHER REGRESSORS "
msg2file " =========================================================="

fileIN="${EPIrun_out}${configs_EPI_resting_file}"

if  [[ ! -e ${fileIN} ]] || [[ ! -d "${EPIrun_out}/${flags_NuisanceReg}" ]]; then
    log "ERROR - ${fileIN} and or ${EPIrun_out}/${flags_NuisanceReg} not found. Connot perform physiological regressors analysis"
    exit 1
fi 

PhReg_path="${EPIrun_out}/${regPath}"

if [[ ! -d ${PhReg_path} ]]; then
    cmd="mkdir ${PhReg_path}"
    log $cmd
    eval $cmd 
fi

if ${flags_EPI_GS}; then
    log " Global signal regression is ON "
else
    log " Global signal regression is OFF - will compute global signal for QC"
    export configs_EPI_numGS=2
fi

if ${configs_EPI_DCThighpass}; then
    log " DCT bases will be included in regression "
else
    log " DCT bases will NOT be included in regression "
    export configs_EPI_dctfMin=0
fi

cmd="python ${EXEDIR}/src/func/other_regressors.py \
     ${fileIN} ${PhReg_path}"
log $cmd
eval $cmd

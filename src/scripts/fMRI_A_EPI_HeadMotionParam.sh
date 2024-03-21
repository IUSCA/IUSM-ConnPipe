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

msg2file "# =========================================================="
msg2file "# 5.1 Head Motion Parameter Regression. "
msg2file "# =========================================================="

if [[ ! -e "${EPIrun_out}/4_epi.nii.gz" ]]; then  

    log "WARNING -- ${EPIrun_out}/4_epi.nii.gz does not exist. Skipping further analysis..."
    exit 1        

fi

HMPpath="${EPIrun_out}/${flags_NuisanceReg}"

# load 6 motion regressors and get derivatives
cmd="python ${EXEDIR}/src/func/load_motion_reg.py ${HMPpath} ${configs_EPI_numReg}"
log $cmd
eval $cmd
if [ $? -eq 0 ]; then
    log --no-datetime "Saved motion regressors and temporal derivatives"
    log --no-datetime "Saved quadratics of motion and its derivatives"
else
    log "WARNING motion regressors and derivatives not saved. Exiting."
fi
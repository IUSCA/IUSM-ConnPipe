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

###################################################################################

log --no-datetime "# =========================================================="
log --no-datetime "# 6. Demean, Detrend, Bandpass "
log --no-datetime "# =========================================================="

if [[ $nR == *_BPF ]]; then
    # Crop out "_BPF" and save the new string into nRc
    nRc="${nR%_BPF}"
    fileIn="${NuisancePhysReg_out}/NuisanceRegression_${nRc}.npz"
    fileOut="${NuisancePhysReg_out}/NuisanceRegression_${nR}"
fi

if [[ ! -e "${fileIn}" ]]; then  
    log " WARNING ${fileIn} not found. Regression might have failed at fMRI_A_EPI_ApplyReg.sh. Exiting..."
    exit 1    
fi 

cmd="python ${EXEDIR}/src/func/dm_dt_bandpass.py \
     ${fileIn} ${fileOut}"
log $cmd
eval $cmd
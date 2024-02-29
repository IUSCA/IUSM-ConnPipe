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

PhReg_path="${EPIrun_out}/${regPath}"
if [[ $nR == *_BPF ]]; then
    # Crop out "_BPF" and save the new string into nRc
    nRc="${nR%_BPF}"
    if ${configs_EPI_despike}; then
        fileIn="${PhReg_path}/NuisanceRegression_${nRc}_despiked.npz"
        fileOut="${PhReg_path}/NuisanceRegression_${nR}_despiked"
    else
        fileIn="${PhReg_path}/NuisanceRegression_${nRc}.npz"
        fileOut="${PhReg_path}/NuisanceRegression_${nR}"
    fi
fi

if [[ ! -e "${fileIn}" ]]; then  
    log " WARNING ${fileIn} not found. Exiting..."
    exit 1    
fi 

cmd="python ${EXEDIR}/src/func/dm_dt_bandpass.py \
     ${fileIn} ${fileOut} ${PhReg_path} ${TR}"
log $cmd
eval $cmd
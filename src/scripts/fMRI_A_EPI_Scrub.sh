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

############################################################################### 

msg2file "# =========================================================="
msg2file "# 8. Scrubbing. "
msg2file "# =========================================================="

if ! $configs_EPI_despike; then

     log "nR is ${nR}"

     # Identify what files to scrub

     fileIn="${NuisancePhysReg_out}/NuisanceRegression_${nR}.npz"

     log --no-datetime "Applying scrubbing on Regression output ${fileIn}"

     checkisfile ${fileIn}    
     fileOut="${NuisancePhysReg_out}/NuisanceRegression_${nR}_scrubbed.npz"
     log "Output file will be named ${fileOut}"
     
     cmd="python ${EXEDIR}/src/func/scrub_vols.py \
          ${NuisancePhysReg_out}"
     log $cmd
     eval $cmd
else
     log "Scubbing is bypassed because configs_EPI_despike=true"
fi
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

     if [[ ${configs_scrub} == "stat_DVARS" ]] || [[ ${configs_scrub} == "fsl_fd_dvars" ]] ; then
          log "nR is ${nR}"

          # Identify what files to scrub

          fileIn="${NuisancePhysReg_out}/NuisanceRegression_${nR}.npz"

          log --no-datetime "Applying scrubbing on Regression output ${fileIn}"

          checkisfile ${fileIn}    

          fileOut="${NuisancePhysReg_out}/NuisanceRegression_${nR}_scrubbed"
          log "Output file will be named ${fileOut}"
          
          cmd="python ${EXEDIR}/src/func/scrub_vols.py \
               ${fileIn} ${fileOut}"
          log $cmd
          eval $cmd
     else
          echoerr "Scrubbing parameter configs_scrub not recognized. Options are: stat_DVARS, fsl_fd_dvars or no_scrub"
          exit 1
     fi
else
     log "WARNING: Scubbing cannot be performed on despiked data! \
          To generated scrubbed data, set configs_EPI_despike=false \
          and rerun the pipeline starting at the regression step, ApplyReg"
fi
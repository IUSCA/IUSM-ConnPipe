
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

log "# =========================================================="
log "# 8. Scrubbing. "
log "# =========================================================="


PhReg_path="${EPIpath}/${regPath}"

post_nR="${nR}"

if ${flags_EPI_DemeanDetrend}; then
    post_nR="${post_nR}_dmdt"
fi

if ${flags_EPI_BandPass}; then
    post_nR="${post_nR}_butter"
fi 

log "nR is ${nR}"
log "post_nR is ${post_nR}"


# Identify what files to scrub
fileIn="${PhReg_path}/NuisanceRegression_${post_nR}.npz"

if [[ ${post_nR} == ${nR} ]]; then 
    log "Applying scrubbing on Regression output ${fileIn}"
else 
    log "Applying scrubbing on post-regression processed output ${fileIn}"
fi
checkisfile ${fileIn}    
fileOut="${PhReg_path}/NuisanceRegression_${post_nR}_scrubbed.npz"
log "Output file will be named ${fileOut}"
 
cmd="python ${EXEDIR}/src/func/scrub_vols.py \
     ${PhReg_path} ${post_nR}"
log $cmd
eval $cmd


# elif [[ "${post_nR}" == "${nR}_dmdt" ]]; then
#     log "=========== demean and detrend only ============="
# elif [[ "${post_nR}" == "${nR}_Butter" ]]; then
#     log "=========== Bandpass only ============="
# elif [[ "${post_nR}" == "${nR}_dmdt_Butter" ]]; then
#     log "=========== dmdt and Bandpass ============="
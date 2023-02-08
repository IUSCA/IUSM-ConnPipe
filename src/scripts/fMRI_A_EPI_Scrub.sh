
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

log "nR is ${nR}"
log "post_nR is ${post_nR}"


# Identify what files to scrub
fileIn="${PhReg_path}/NuisanceRegression_${post_nR}.npz"
log "Applying scrubbing on ${fileIn}"

checkisfile ${fileIn}    
fileOut="${PhReg_path}/NuisanceRegression_${post_nR}_scrubbed.npz"
log "Output file will be named ${fileOut}"
 
cmd="python ${EXEDIR}/src/func/scrub_vols.py \
     ${PhReg_path} ${post_nR}"
log $cmd
eval $cmd


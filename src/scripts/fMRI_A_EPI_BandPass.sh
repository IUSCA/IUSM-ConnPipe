
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
log "# 7. Bandpass. "
log "# =========================================================="



PhReg_path="${EPIpath}/${regPath}"

# Make sure files exist
# if ${flags_EPI_DemeanDetrend}; then 
    fileIn="${PhReg_path}/NuisanceRegression_${post_nR}.npz"
    fileOut="${PhReg_path}/NuisanceRegression_${post_nR}_butter"
# else
#     fileIn="${PhReg_path}/NuisanceRegression_${nR}.npz"
#     fileOut="${PhReg_path}/NuisanceRegression_${nR}_butter"
# fi

log "Using ${fileIn}"

if [[ ! -e "${fileIn}" ]]; then  
    log " WARNING ${fileIn} not found. Exiting..."
    exit 1    
fi 

log "Output file will be named ${fileOut}"

cmd="python ${EXEDIR}/src/func/apply_bandpass.py \
     ${PhReg_path} ${TR} \
     ${fileOut}"
log $cmd
eval $cmd
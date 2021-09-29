
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


log "# =========================================================="
log "# 6. Demean and Detrend. "
log "# =========================================================="


PhReg_path="${EPIpath}/${regPath}"
fileIn="${PhReg_path}/NuisanceRegression_${nR}.npz"
fileOut="${PhReg_path}/NuisanceRegression_${nR}_dmdt"

if [[ ! -e "${fileIn}" ]]; then  
    log " WARNING ${fileIn} not found. Exiting..."
    exit 1    
fi 

cmd="python ${EXEDIR}/src/func/demean_detrend.py \
     ${fileIn} ${fileOut}"
log $cmd
eval $cmd





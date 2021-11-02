
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

echo "# =========================================================="
echo "# 5.1 Head Motion Parameter Regression. "
echo "# =========================================================="

if [[ ! -e "${EPIpath}/4_epi.nii.gz" ]]; then  

    log "WARNING -  ${EPIpath}/4_epi.nii.gz does not exist. Skipping further analysis..."
    exit 1        

fi


HMPpath="${EPIpath}/${flags_NuisanceReg}"
if [[ ! -d ${HMPpath} ]]; then
    cmd="mkdir ${HMPpath}"
    log $cmd
    eval $cmd 
fi


# load 6 motion regressors and get derivatives
cmd="python ${EXEDIR}/src/func/load_motion_reg.py ${HMPpath} ${configs_EPI_numReg}"
log $cmd
eval $cmd
if [ $? -eq 0 ]; then
    log "Saved motion regressors and temporal derivatives"
    log "Saved quadratics of motion and its derivatives"
else
    log "WARNING motion regressors and derivatives not saved. Exiting."
fi
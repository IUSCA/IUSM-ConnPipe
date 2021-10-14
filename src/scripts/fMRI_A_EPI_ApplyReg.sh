
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

## PHYSIOLOGICAL REGRESSORS
msg2file "=========================================================="
msg2file "              5.3 APPLY REGRESSORS "
msg2file " =========================================================="

if [[ ${flags_NuisanceReg} == "AROMA" ]]; then
    log "nuisanceReg AROMA"
    export configs_EPI_numReg=0
elif [[ ${flags_NuisanceReg} == "HMPreg" ]]; then
    log "nuisanceReg HMPreg"
fi

if [[ ${flags_PhysiolReg} == "aCompCor" ]]; then  
    log "PhysiolReg - aCompCorr"

elif [[ ${flags_PhysiolReg} == "meanPhysReg" ]]; then
    log "PhysiolReg - Mean CSF & WM signal"
fi 


if ! ${flags_EPI_GS}; then
    export configs_EPI_numGS=0
fi

if ! ${configs_EPI_DCThighpass}; then
    export configs_EPI_dctfMin=0
fi


if ${flags_EPI_DVARS}; then
    log "filename postfix for output image -- ${nR}_DVARS"
else
    log "filename postfix for output image -- ${nR}"
fi

cmd="python ${EXEDIR}/src/func/apply_reg.py \
     ${flags_NuisanceReg} ${configs_EPI_numPhys} \
     ${flags_PhysiolReg}"
log $cmd
eval $cmd
 


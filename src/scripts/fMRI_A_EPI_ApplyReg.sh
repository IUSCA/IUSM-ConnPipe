
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

if ${flags_NuisanceReg_AROMA}; then
    log "nuisanceReg AROMA"
    nuisanceReg="AROMA"
    export configs_EPI_numReg=0
elif ${flags_NuisanceReg_HeadParam}; then
    log "nuisanceReg HMParam"
    nuisanceReg="HMPreg"  
fi


if ! ${flags_EPI_GS}; then
    export configs_EPI_numGS=0
fi

if ! ${configs_EPI_DCThighpass}; then
    export configs_EPI_dctfMin=0
fi

if ${flags_PhysiolReg_aCompCorr}; then  
    log "PhysiolReg - aCompCorr"
    physReg="aCompCorr"
    config_param=${configs_EPI_numPC}

elif ${flags_PhysiolReg_WM_CSF}; then
    log "PhysiolReg - Mean CSF & WM signal"
    physReg="PhysReg" #"Mn_WM_CSF"
    config_param=${configs_EPI_numPhys}    
fi 

if ${flags_EPI_DVARS}; then
    log "filename postfix for output image -- ${nR}_DVARS"
else
    log "filename postfix for output image -- ${nR}"
fi

cmd="python ${EXEDIR}/src/func/apply_reg.py \
     ${nuisanceReg} ${config_param} \
     ${physReg}"
log $cmd
eval $cmd


# log "calling python script"
# cmd="apply_reg \
#     ${nuisanceReg} ${config_param} \
#     ${physReg}"
# log $cmd
# eval $cmd      


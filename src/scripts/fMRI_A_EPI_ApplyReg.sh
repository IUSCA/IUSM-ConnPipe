
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


if ${flags_EPI_DVARS}; then
    log "filename postfix for output image -- ${nR}_DVARS"
else
    log "filename postfix for output image -- ${nR}"
fi

if ${flags_EPI_GS}; then
    log " Global signal regression is ON "
else
    log " Global signal regression is OFF "
    export configs_EPI_numGS=0
fi

if ${configs_EPI_DCThighpass}; then
    log " DCT bases will be included in regression "
else
    log " DCT bases will NOT be included in regression "
    export configs_EPI_dctfMin=0
fi

cmd="python ${EXEDIR}/src/func/apply_reg.py \
     ${flags_NuisanceReg} ${flags_PhysiolReg}"
log $cmd
eval $cmd
 


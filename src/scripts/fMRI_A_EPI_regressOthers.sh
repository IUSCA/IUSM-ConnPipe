
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
msg2file " =========================================================="
msg2file "                5.3 OTHER REGRESSORS "
msg2file " =========================================================="


if [[ ${flags_NuisanceReg} == "AROMA" ]]; then   

    fileIN="${EPIpath}/AROMA/AROMA-output/denoised_func_data_nonaggr.nii.gz"
    if  [[ ! -e ${fileIN} ]]; then
        log "ERROR ${fileIN} not found. Connot perform regresso analysis"
        exit 1
    fi

elif [[ ${flags_NuisanceReg} == "HMPreg" ]]; then 

    fileIN="${EPIpath}/4_epi.nii.gz"
    if  [[ ! -e ${fileIN} ]] || [[ ! -d "${EPIpath}/HMPreg" ]]; then
        log "ERROR ${fileIN} and or ${EPIpath}/HMPreg not found. Connot perform physiological regressors analysis"
        exit 1
    fi 
fi

PhReg_path="${EPIpath}/${regPath}"

if [[ ! -d ${PhReg_path} ]]; then
    cmd="mkdir ${PhReg_path}"
    log $cmd
    eval $cmd 
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

#other_regressors ${EPIpath} ${fileIN} ${PhReg_path}

cmd="python ${EXEDIR}/src/func/other_regressors.py \
     ${fileIN} ${PhReg_path}"
log $cmd
eval $cmd

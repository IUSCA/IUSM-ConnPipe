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
msg2file "            5.2 PHYSIOLOGICAL REGRESSORS "
msg2file "=========================================================="

fileIN="${EPIrun_out}${configs_EPI_resting_file}"
log --no-datetime "EPI Input:"
log --no-datetime "${fileIN}"

if [[ ${configs_NuisanceReg} == "AROMA" ]]; then   

    if  [[ -e ${fileIN} ]]; then
        if [[ ${configs_PhysiolReg} == "aCompCor" ]]; then  
            log --no-datetime "----------------- PhysiolReg - Combining aCompCorr with AROMA output data -----------------"
        elif [[ ${configs_PhysiolReg} == "meanPhysReg" ]]; then
            log --no-datetime "----------- PhysiolReg - Combining Mean CSF & WM signal with AROMA output data ------------"
        fi          
    else
        log "ERROR ${fileIN} not found. Connot perform physiological regressors analysis"
        exit 1
    fi 

elif [[ ${configs_NuisanceReg} == "HMPreg" ]]; then 

    if  [[ -e ${fileIN} ]] && [[ -d "${EPIrun_out}/HMPreg" ]]; then
        if [[ ${configs_PhysiolReg} == "aCompCor" ]]; then   
            log --no-datetime "----------------- PhysiolReg - Combining aCompCorr with HMP regressors -----------------"
        elif [[ ${configs_PhysiolReg} == "meanPhysReg" ]]; then
            log --no-datetime "----------- PhysiolReg - Combining Mean CSF & WM signal with HMP regressors ------------"
        fi          
    else
        log "ERROR ${fileIN} and/or ${EPIrun_out}/HMPreg not found. Connot perform physiological regressors analysis"
        exit 1
    fi 

elif [[ ${configs_NuisanceReg} == "AROMA_HMP" ]]; then 

    if  [[ -e ${fileIN} ]] && [[ -d "${EPIrun_out}/AROMA_HMP" ]]; then
        if [[ ${configs_PhysiolReg} == "aCompCor" ]]; then   
            log --no-datetime "----------------- PhysiolReg - Combining aCompCorr with AROMA+HMP regressors -----------------"
        elif [[ ${configs_PhysiolReg} == "meanPhysReg" ]]; then
            log --no-datetime "----------- PhysiolReg - Combining Mean CSF & WM signal with AROMA+HMP regressors ------------"
        fi          
    else
        log "ERROR ${fileIN} and/or ${EPIrun_out}/AROMA_HMP not found. Connot perform physiological regressors analysis"
        exit 1
    fi 
fi

# read in data and masks 
cmd="python ${EXEDIR}/src/func/read_physiol_data.py"
log $cmd
eval $cmd

# fill holes in the brain mask, without changing FOV
fileOut="${EPIrun_out}/rT1_brain_mask_FC.nii.gz"
cmd="fslmaths ${fileOut} -fillh ${fileOut}"
log $cmd
eval $cmd

cmd="python ${EXEDIR}/src/func/physiological_regressors.py \
    ${fileIN} ${configs_PhysiolReg} \
    ${configs_EPI_numPhys} ${NuisancePhysReg_out}"
log $cmd
eval $cmd
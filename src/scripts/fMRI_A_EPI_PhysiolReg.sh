
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
msg2file "            5.2 PHYSIOLOGICAL REGRESSORS "
msg2file "=========================================================="

if ${flags_PhysiolReg_aCompCorr}; then  
    log "- -----------------aCompCor---------------------"      
elif ${flags_PhysiolReg_WM_CSF}; then
    log "- -----------------Mean CSF and WM Regression-----------------"
fi 

if ${flags_NuisanceReg_AROMA}; then   

    fileIN="${EPIpath}/AROMA/AROMA-output/denoised_func_data_nonaggr.nii.gz"
    if  [[ -e ${fileIN} ]]; then
        if ${flags_PhysiolReg_aCompCorr}; then  
            log "PhysiolReg - Combining aCompCorr with AROMA output data"
        elif ${flags_PhysiolReg_WM_CSF}; then
            log "PhysiolReg - Combining Mean CSF & WM signal with AROMA output data"
            configs_EPI_numPC=0
        fi          
    else
        log "ERROR ${fileIN} not found. Connot perform physiological regressors analysis"
        exit 1
    fi 

elif ${flags_NuisanceReg_HeadParam}; then 

    fileIN="${EPIpath}/4_epi.nii.gz"
    if  [[ -e ${fileIN} ]] && [[ -d "${EPIpath}/HMPreg" ]]; then
        if ${flags_PhysiolReg_aCompCorr}; then  
            log "PhysiolReg - Combining aCompCorr with HMP regressors"
        elif ${flags_PhysiolReg_WM_CSF}; then
            log "PhysiolReg - Combining Mean CSF & WM signal with HMP regressors"
            configs_EPI_numPC=0
        fi          
    else
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

# read in data and masks 
cmd="python ${EXEDIR}/src/func/read_physiol_data.py"
log $cmd
eval $cmd

# fill holes in the brain mask, without changing FOV
fileOut="${EPIpath}/rT1_brain_mask_FC.nii.gz"
cmd="fslmaths ${fileOut} -fillh ${fileOut}"
log $cmd
eval $cmd

cmd="python ${EXEDIR}/src/func/physiological_regressors.py \
    ${fileIN} ${flags_PhysiolReg_aCompCorr} \
    ${configs_EPI_numPC} ${PhReg_path}"
log $cmd
eval $cmd



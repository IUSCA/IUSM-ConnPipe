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

msg2file "# ==========================================="
msg2file "# 2. Motion Correction"
msg2file "# ==========================================="

if [[ ! -e "${EPIrun_out}/1_epi.nii.gz" ]]; then  
    log "No slice time corrected 1_epi output found"
    log --no-datetime "Defaulting to 0_epi data."
    if [[ ! -e "${EPIrun_out}/0_epi_unwarped.nii.gz" ]]; then 
        log --no-datetime "Unwarped 0_epi volume does not exist"
        fileIn="${EPIrun_out}/0_epi.nii.gz"
        if [[ -e "${fileIn}" ]]; then 
            log --no-datetime "Will use 0_epi from dicom conversion."
        else
            log "WARNING No 0_epi inputs found... Exiting"
            exit 1
        fi
    else
        fileIn="${EPIrun_out}/0_epi_unwarped.nii.gz"
        log --no-datetime "Will use 0_epi_unwarped.nii.gz"
    fi 
else
    fileIn="${EPIrun_out}/1_epi.nii.gz"
    log --no-datetimne "Will use the slice time corrected 1_epi.nii.gz as input" 
fi 

cmd="fslval ${fileIn} dim4"
log $cmd 
nvols=`$cmd`  
echo "export nvols=${nvols}" >> ${EPIrun_out}/0_param_dcm_hdr.sh
qc "Number of Time Points: ${nvols} "


log --no-datetime "MotionCorr fileIn is ${fileIn}"
# Compute motion outliers
cmd="${EXEDIR}/src/scripts/get_motion_outliers.sh ${EPIrun_out} ${fileIn} ${nvols}"
log --no-datetime $cmd
eval $cmd

if [[ ! $? -eq 0 ]]; then
    exit 1
fi

fileOut="${EPIrun_out}/2_epi"
cmd="mcflirt -in ${fileIn} -out ${fileOut} -plots -meanvol"
log $cmd 
eval $cmd 

cmd="mv ${EPIrun_out}/2_epi.par ${EPIrun_out}/motion.txt"
log --no-datetime $cmd 
eval $cmd 

cmd="rm ${EPIrun_out}/2_epi_mean_reg.nii.gz"
log --no-datetime $cmd 
eval $cmd 
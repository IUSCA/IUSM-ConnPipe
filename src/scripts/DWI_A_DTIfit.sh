#!/bin/bash
#
# Script: f_preproc_DWI.m adaptaion from Matlab script 
#
###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

############################################################################### 

msg2file "=================================="
msg2file "2. Fitting Diffusion Tensor"
msg2file "=================================="
    
export EDDYpath="${DWIpath}/EDDY"
   
## Path to eddy subdirectory
if [[ ! -d "${DTpath}" ]]; then
    log " Creating DTIfit subdirectory."
    mkdir -p ${DTpath}
else
    log "Purging existing DTIfit subdirectory."
    # remove any existing files
    rm -rf ${DTpath}/*
    log "rm -rf ${DTpath}/*"
fi
log "DTIfit directory is ${DTpath}"

# Prepare inputs for DTIfit:

# DWI data in (from EDDY)
fileDWI="${EDDYpath}/eddy_output.nii.gz"

if [[ "$rtag" -eq 1 ]]; then
    fileInBval="${DWIpath}/0_DWI_AP-PA.bval"


elif [[ "$rtag" -gt 1 ]]; then
    fileInBval="${fileBval}"


fi

# Format Bval file (row format)
cmd="python ${EXEDIR}/src/func/format_row_bval.py ${DTpath} ${fileInBval%%.*}"  
log $cmd
eval $cmd 2>&1 | tee -a ${logfile_name}.log

fileDTIfitBval="${DTpath}/3_DWI.bval"

# Rotated Bvec from EDDY will be used here.
fileEddyBvec="${EDDYpath}/eddy_output.eddy_rotated_bvecs"

# Create a brain mask of EDDY corrected data
cmd="python ${EXEDIR}/src/func/extract_b0_1st.py \
    ${fileDTIfitBval}"
log $cmd
b0_1st=$(eval $cmd)
log "b0_1st is ${b0_1st}"

if [[ "${b0_1st}" == "err" ]]; then
    log "WARNING: No b0 volumes identified. Check quality of ${fileDTIfitBval}"
    exit 1
else
    echo "FSL index of 1st b0 volume is ${b0_1st}"
    fileb0="${DTpath}/b0_1st.nii.gz"  #file out b0
    # extract b0 into 3D volume
    cmd="fslroi ${fileDWI} ${fileb0} ${b0_1st} 1"
    log $cmd
    eval $cmd

    # brain extraction of b0
    cmd="bet ${fileb0} ${fileb0} -f ${configs_DWI_DTIfitf} -m"
    log $cmd
    eval $cmd

    fileMask="${DTpath}/b0_1st_mask.nii.gz"
    # output base name
    fileOut="${DTpath}/3_DWI"

    #run DTIfit
    cmd="dtifit -k ${fileDWI} \
        -o ${fileOut} \
        -m ${fileMask} \
        -r ${fileEddyBvec} \
        -b ${fileDTIfitBval} \
        ${configs_DWI_DTIfitargs} --save_tensor -V"
        
    log $cmd
    eval $cmd > "${DTpath}/dtifit.log"

    # Preproc DWI_A is done.
    log "DWI_A is done."
fi 

echo "QC recommendations:"
echo "1. Check topup_field.nii.gz in UNWARP"
echo "2. Check delta_DWI.nii.gz in EDDY"
echo "2b. If eddy_correct was ran check eddy_output also"
echo "3. Check 3_DWI_V1.nii.gz in DTIfit, with FSLeyes"

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

function extract_b0_1st() {
pbval="$1" python - <<END
import os
import numpy as np

#DWIpath=os.environ['DWIpath']
# print(DWIpath)
pbval=os.environ['pbval']
#print("dwifile ",dwifile)

def is_empty(any_struct):
    if any_struct:
        return False
    else:
        return True 

#pbval=''.join([DWIpath,'/',dwifile,'.bval'])
bval = np.loadtxt(pbval)

B0_index = np.where(bval==0)
if is_empty(B0_index):    
    #print("No B0 volumes identified. Check quality of .bval") 
    print("err")
else:   
    b0_1st = np.argmin(bval)
    print(b0_1st)

END
}


############################################################################### 


echo "=================================="
echo "2. Fitting Diffusion Tensor"
echo "=================================="

log "Number of scans is ${nscanmax}"

for ((nscan=1; nscan<=nscanmax; nscan++)); do  #1 or 2 DWI scans

    if ${configs_DWI_DICOMS2_B0only} && [[ "$nscan" -eq 2 ]]; then
        log "WARNING skipping DTIfit for DICOMS2"
    else
        
        # set paths
        path_DWI_UNWARP=${DWIpath}/${configs_unwarpFolder}
        if [[ "${nscanmax}" -eq "1" ]]; then 
            export path_DWI_EDDY="${DWIpath}/EDDY"
            export path_DWI_DTIfit="${DWIpath}/DTIfit"
        elif [[ "${nscanmax}" -eq "2" ]]; then 
            export path_DWI_EDDY="${DWIpath}/EDDY${nscan}"
            export path_DWI_DTIfit="${DWIpath}/DTIfit${nscan}"
        fi 

        # create output directory if one does not exist
        if [[ ! -d "${path_DWI_DTIfit}" ]]; then
            cmd="mkdir ${path_DWI_DTIfit}"
            log $cmd
            eval $cmd
        else 
            # remove any existing files
            rm -rf ${path_DWI_DTIfit}/*
            log "rm -rf ${path_DWI_DTIfit}/"
        fi 

        # Prepare inputs for DTIfit
        # DWI data in (from EDDY)
        fileDWI="${path_DWI_EDDY}/eddy_output.nii.gz"

     #   if [[ "$nscanmax" -eq "1" ]]; then 
           # dwifile="0_DWI"
            #b0file="AP_b0"
      #  elif [[ "$nscanmax" -eq "2" ]]; then 
           # dwifile="0_DWI_ph${nscan}"
            #b0file=ph${nscan}_b0_
       # fi 
        # Format Bval file (row format)
        cmd="python ${EXEDIR}/src/func/format_row_bval.py ${path_DWI_DTIfit} ${fileBval::-5}"
        log $cmd
        eval $cmd
        fileDTIfitBval="${path_DWI_DTIfit}/3_DWI.bval"

        # Rotated Bvec from EDDY will be used here.
        fileEddyBvec="${path_DWI_EDDY}/eddy_output.eddy_rotated_bvecs"

        # Create a brain mask of EDDY corrected data
        b0_1st=$(extract_b0_1st ${fileDTIfitBval})
        #log "b0_1st is ${b0_1st}"

        if [[ "${b0_1st}" == "err" ]]; then
            log "WARNING: No b0 volumes identified. Check quality of 0_DWI.bval"
            exit 1
        else
            echo "FSL index of 1st b0 volume is ${b0_1st}"
            fileb0="${path_DWI_DTIfit}/b0_1st.nii.gz"  #file out b0
            # extract b0 into 3D volume
            cmd="fslroi ${fileDWI} ${fileb0} ${b0_1st} 1"
            log $cmd
            eval $cmd

            # brain extraction of b0
            cmd="bet ${fileb0} ${fileb0} -f ${configs_DWI_DTIfitf} -m"
            log $cmd
            eval $cmd

            fileMask="${path_DWI_DTIfit}/b0_1st_mask.nii.gz"
            # output base name
            fileOut="${path_DWI_DTIfit}/3_DWI"

            #run DTIfit
            cmd="dtifit -k ${fileDWI} \
                -o ${fileOut} \
                -m ${fileMask} \
                -r ${fileEddyBvec} \
                -b ${fileDTIfitBval} --save_tensor -V"
            log $cmd
            eval $cmd > "${path_DWI_DTIfit}/dtifit.log"

            # Preproc DWI_A is done.
            log "DWI_A is done."
        
        fi 

    fi 

done

echo "QC recommendations:"
echo "1. Check topup_field.nii.gz in UNWARP"
echo "2. Check delta_DWI.nii.gz in EDDY"
echo "2b. If eddy_correct was ran check eddy_output also"
echo "3. Check 3_DWI_V1.nii.gz in DTIfit, with FSLeyes"

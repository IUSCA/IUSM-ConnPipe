
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

function extract_b0_images() {
path="$1" python - <<END
import os
import numpy as np

DWIpath=os.environ['path']
# print(DWIpath)

def is_empty(any_struct):
    if any_struct:
        return False
    else:
        return True 

# DWIpath='/N/dc2/scratch/aiavenak/testdata/10692_1_AAK/DWI'

pbval=''.join([DWIpath,'/0_DWI.bval'])
bval = np.loadtxt(pbval)
# print(bval)

B0_index = np.where(bval<=1)
# print(B0_index)

if is_empty(B0_index):    
    #print("No B0 volumes identified. Check quality of 0_DWI.bval") 
    print(0)
else:   
    b0file = ''.join([DWIpath,"/b0file.txt"])
    ff = open(b0file,"w+")
    for i in np.nditer(B0_index):
        ff.write("%s\n" % i)
    ff.close()
    print(1)

END
}

############################################################################### 


echo "=================================="
echo "2. Fitting Diffusion Tensor"
echo "=================================="

# set paths 
path_DWI_UNWARP=${DWIpath}/${configs_unwarpFolder}

path_DWI_EDDY="${DWIpath}/EDDY"
path_DWI_DTIfit="${DWIpath}/DTIfit"

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

# Format Bval file (row format)
res=$(extract_b0_images ${DWIpath})

if [[ ${res} -ne "1" ]]; then
    log "WARNING: No b0 volumes identified. Check quality of 0_DWI.bval"
else
    log "B0 indices identified: "
    B0_indices="${DWIpath}/b0file.txt"
    fileIn="${DWIpath}/0_DWI.nii.gz"
    nB0=0

    while IFS= read -r b0_index
    do 
        echo "$b0_index"
        nB0=$(echo $nB0+1 | bc) ## number of B0 indices 

        fileOut="${path_DWI_EDDY}/AP_b0_${b0_index}.nii.gz"

        cmd="fslroi ${fileIn} ${fileOut} ${b0_index} 1"
        log $cmd
        eval $cmd
    done < "$B0_indices"

fi 
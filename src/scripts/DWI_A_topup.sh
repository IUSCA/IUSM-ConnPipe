

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
        # fn = "/AP_b0_%d.nii.gz" % i
        # fileOut = "AP_b0_%d.nii.gz" % i
        # fileOut = ''.join([DWIpath,fn])
        ff.write("%s\n" % i)
        # print(fileOut)
    ff.close()
    print(1)

END
}


############################################################################### 


echo "=================================="
echo "1. Topup Field Estimation"
echo "=================================="

# set paths to opposite phase encoded images
path_DWI_UNWARP=${DWIpath}/${configs_unwarpFolder}

path_DWIdcmPA=${path_DWI_UNWARP}/${configs_dcmPA}

if [[ ! -d "${path_DWI_UNWARP}" ]]; then
    log "WARNING No UNWARP dicom directory found! Skipping topup."
elif [[ ! -d "${path_DWIdcmPA}" ]]; then
    log "WARNING No dicom directory found within UNWARP! Skipping topup."    
elif [ -z "$(ls -A ${path_DWIdcmPA})" ]; then  #check if dir is empty 
    log "No files found within UNWARP dicom directory! Skipping topup."
else
    # remove files from previous run(s)
    log "rm -f ${path_DWI_UNWARP}/.nii.gz \
        ${path_DWI_UNWARP}/.log \
        ${path_DWI_UNWARP}/.txt"

    rm -f ${path_DWI_UNWARP}/*.nii.gz \
    ${path_DWI_UNWARP}/*.log \
    ${path_DWI_UNWARP}/*.txt

    # Extract b0 volumes from dataset
    res=$(extract_b0_images ${DWIpath})
    echo "res is ${res}"

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

            fileOut="${path_DWI_UNWARP}/AP_b0_${b0_index}.nii.gz"

            cmd="fslroi ${fileIn} ${fileOut} ${b0_index} 1"
            log $cmd
            eval $cmd
        done < "$B0_indices"

        rm -f ${B0_indices}  
    fi 

    # Dicom import the PA volume
    ## remove existing files
    cmd="rm -rf ${path_DWI_UNWARP}/PA_b0.nii.gz"
    log $cmd
    eval $cmd 

    ## dicom import
    cmd="dcm2niix -f PA_b0 -o ${path_DWI_UNWARP} -v y ${path_DWIdcmPA}"
    log $cmd
    eval $cmd > "${path_DWI_UNWARP}/dcm2niix.log"  ##save log file

    ## gzip output image
    cmd="gzip ${path_DWI_UNWARP}/PA_b0.nii"
    log $cmd
    eval $cmd 

    # Concatenate AP and PA into a single 4D volume.
    # create a list of AP volume names
    ## list all the files in unwarp dir

# declare -a fileList
# while IFS= read -r -d $'\0' REPLY; do 
#     fileList+=( "$REPLY" )
# done < <(ffind ${path_DWI_UNWARP} -maxdepth 1 -type f -iname "*.nii.gz" -print0)

    filesIn=$(find ${path_DWI_UNWARP} -maxdepth 1 -type f -iname "*.nii.gz")
    echo $filesIn
    B0_list=$(find ${path_DWI_UNWARP} -maxdepth 1 -type f -iname "*.nii.gz" | wc -l)
    echo "$B0_list AP volumes were found in ${path_DWI_UNWARP}"

    ## merge into a 4D volume
    fileOut="${path_DWI_UNWARP}/AP_PA_b0.nii.gz"

    cmd="fslmerge -t ${fileOut} ${filesIn}"
    log $cmd
    eval $cmd 

    ## generate acqparams.txt necessary for topup
    PAcount=$(echo $B0_list - $nB0 | bc)

    APline="0 -1 0 ${configs_DWI_readout}"
    PAline="0 1 0 ${configs_DWI_readout}"
    
    for ((i = 0; i < $nB0; i++)); do
        echo $APline >> "${path_DWI_UNWARP}/acqparams.txt"
    done


    for ((i = 0; i < $PAcount; i++)); do
        echo $PAline >> "${path_DWI_UNWARP}/acqparams.txt"
    done

    # Run Topup
    fileIn="${path_DWI_UNWARP}/AP_PA_b0.nii.gz"
    fileParams="${path_DWI_UNWARP}/acqparams.txt"
    fileOutName="${path_DWI_UNWARP}/topup_results"
    fileOutField="${path_DWI_UNWARP}/topup_field"
    fileOutUnwarped="${path_DWI_UNWARP}/topup_unwarped"

    cmd="topup --imain=${fileIn} \
     --datain=${fileParams} \
     --out=${fileOutName} \
     --fout=${fileOutField} \
     --iout=${fileOutUnwarped}"

     log $cmd
     eval $cmd 

    
fi







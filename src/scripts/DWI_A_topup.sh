

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
path="$1" dwifile="$2" nscan="$3" python - <<END
import os
import numpy as np

DWIpath=os.environ['path']
# print(DWIpath)
dwifile=os.environ['dwifile']
#print(dwifile)
configs_DWI_b0cut = int(os.environ['configs_DWI_b0cut'])
#print(configs_DWI_b0cut)
nscan = os.environ['nscan']

def is_empty(any_struct):
    if any_struct:
        return False
    else:
        return True 

pbval=''.join([DWIpath,'/',dwifile,'.bval'])
bval = np.loadtxt(pbval)
# print(bval)

B0_index = np.where(bval<=configs_DWI_b0cut)
# print(B0_index)

if is_empty(B0_index):    
    #print("No B0 volumes identified. Check quality of 0_DWI.bval") 
    print(0)
else:   
    b0file = ''.join([DWIpath,'/b0indices',nscan,'.txt'])
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

if [[ "$nscanmax" -eq 1 ]]; then
    log "WARNING topup can only be applied to two scan data"
    log "please read documentation to apply topup on your data"
    exit 1
fi

# set paths to opposite phase encoded images
path_DWI_UNWARP=${DWIpath}/${configs_unwarpFolder}

path_DWIdcmPA=${path_DWI_UNWARP}/${configs_dcmPA}

if [[ -d ${path_DWI_UNWARP} ]]; then 
    log "${path_DWI_UNWARP} directory already exists, deleting all files"
    # remove files from previous run(s)
    log "rm -f ${path_DWI_UNWARP}/"

    rm -fr ${path_DWI_UNWARP}/*

else
    log "Creting ${path_DWI_UNWARP} directory"
    cmd="mkdir ${path_DWI_UNWARP}"
    log $cmd
    eval $cmd 
fi

log "Number of scans is ${nscanmax}"
    # Extract b0 volumes from dataset
for ((nscan=1; nscan<=nscanmax; nscan++)); do  #1 or 2 DWI scans
          
    dwifile="0_DWI_ph${nscan}"
    b0file=ph${nscan}_b0_

    res=$(extract_b0_images ${DWIpath} ${dwifile} ${nscan})
    echo "res is ${res}"

    if [[ "${res}" -ne "1" ]]; then
        log "WARNING: No b0 volumes identified. Check quality of 0_DWI.bval"
    else
        log "B0 indices identified: "
        B0_indices="${DWIpath}/b0indices${nscan}.txt"
        fileIn="${DWIpath}/${dwifile}.nii.gz"
        nB0=0
        while IFS= read -r b0_index
        do 
            echo "$b0_index"
            nB0=$(echo $nB0+1 | bc) ## number of B0 indices 

            fileOut="${path_DWI_UNWARP}/${b0file}${b0_index}.nii.gz"

            cmd="fslroi ${fileIn} ${fileOut} ${b0_index} 1"
            log $cmd
            eval $cmd
        done < "$B0_indices"
    fi 
done 


## list all the files in unwarp dir
filesIn=$(find ${path_DWI_UNWARP} -maxdepth 1 -type f -iname "*.nii.gz")
echo $filesIn
B0_list=$(find ${path_DWI_UNWARP} -maxdepth 1 -type f -iname "*.nii.gz" | wc -l)
echo "$B0_list volumes were found in ${path_DWI_UNWARP}"

## merge into a 4D volume
fileOut="${path_DWI_UNWARP}/All_b0.nii.gz"

cmd="fslmerge -t ${fileOut} ${filesIn}"
log $cmd
eval $cmd 

## generate acqparams.txt necessary for topup
PAcount=$(echo $B0_list - $nB0 | bc)

log "PAcount is ${PAcount}"

APline=${DWIdcm_phase_1}
PAline=${DWIdcm_phase_2}

for ((i = 0; i < $nB0; i++)); do
    echo $APline >> "${path_DWI_UNWARP}/acqparams.txt"
done


for ((i = 0; i < $PAcount; i++)); do
    echo $PAline >> "${path_DWI_UNWARP}/acqparams.txt"
done

# Run Topup
fileIn="${path_DWI_UNWARP}/All_b0.nii.gz"
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
    #eval $cmd 
  

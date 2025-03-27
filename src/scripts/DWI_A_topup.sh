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

# Load packages/modules
#===========================================================================
module load ${fsl}

############################################################################### 

msg2file "=================================="
msg2file "1. Topup Field Estimation"
msg2file "=================================="

if [[ "$rtag" -eq 3 ]]; then
    log "WARNING topup can only be applied to two scan data"
    log "please read documentation to apply topup on your data"
    exit 1
fi

## Path to topup subdirectory
if [[ -d "${TOPUPpath}" ]]; then
        log "Purging files from existing topup directory..."
        rm -fr ${TOPUPpath}/*
else
    log "Creating topup directory..."
    mkdir -p ${TOPUPpath}
fi

cmd="python ${EXEDIR}/src/func/index_b0_images.py \
     ${DWIpath} ${fileBval} ${configs_DWI_b0cut} "AP""
log $cmd
eval $cmd 2>&1 | tee -a ${logfile_name}.log

log "AP B0 indices identified: "
B0_indices="${DWIpath}/b0indicesAP.txt"
      
APnB0=0
while IFS= read -r b0_index
do 
    echo "$b0_index"
    APnB0=$(echo $APnB0+1 | bc) ## number of B0 indices 

    fileOut="${TOPUPpath}/AP_b0_${b0_index}.nii.gz"

    cmd="fslroi ${fileNifti} ${fileOut} ${b0_index} 1"
    log $cmd
    eval $cmd
done < "$B0_indices"

if [[ "$rtag" -eq 1 ]]; then
    cmd="python ${EXEDIR}/src/func/index_b0_images.py \
     ${DWIpath} ${fileBvalPA} ${configs_DWI_b0cut} "PA""
    log $cmd
    eval $cmd 2>&1 | tee -a ${logfile_name}.log
    export PAnifti="${fileNiftiPA}"

elif [[ "$rtag" -eq 2 ]]; then
    cmd="python ${EXEDIR}/src/func/index_b0_images.py \
     ${DWIpath} ${fileBvalb0PA} ${configs_DWI_b0cut} "PA""
    log $cmd
    eval $cmd 2>&1 | tee -a ${logfile_name}.log
    export PAnifti="${fileNiftib0PA}"
fi

log "PA B0 indices identified: "
B0_indices="${DWIpath}/b0indicesPA.txt"
      
PAnB0=0
while IFS= read -r b0_index
do 
    echo "$b0_index"
    PAnB0=$(echo $PAnB0+1 | bc) ## number of B0 indices 

    fileOut="${TOPUPpath}/PA_b0_${b0_index}.nii.gz"

    cmd="fslroi ${PAnifti} ${fileOut} ${b0_index} 1"
    log $cmd
    eval $cmd
done < "$B0_indices"

## list all the files in unwarp dir
filesIn=$(find ${TOPUPpath} -maxdepth 1 -type f -iname "*.nii.gz" | sort -n)
echo $filesIn
B0_list=$(find ${TOPUPpath} -maxdepth 1 -type f -iname "*.nii.gz" | wc -l)
echo "$B0_list volumes were found in ${TOPUPpath}"

## merge into a 4D volume
fileOut="${TOPUPpath}/All_b0.nii.gz"

cmd="fslmerge -t ${fileOut} ${filesIn}"
log $cmd
eval $cmd 

## generate acqparams.txt necessary for topup

for ((i = 0; i < $APnB0; i++)); do
    echo $APline >> "${TOPUPpath}/acqparams.txt"
done

for ((i = 0; i < $PAnB0; i++)); do
    echo $PAline >> "${TOPUPpath}/acqparams.txt"
done

# Run Topup
fileIn="${TOPUPpath}/All_b0.nii.gz"
fileParams="${TOPUPpath}/acqparams.txt"
fileOutName="${TOPUPpath}/topup_results"
fileOutField="${TOPUPpath}/topup_field"
fileOutUnwarped="${TOPUPpath}/topup_unwarped"

cmd="topup --imain=${fileIn} \
    --datain=${fileParams} \
    --out=${fileOutName} \
    --fout=${fileOutField} \
    --iout=${fileOutUnwarped}"

    log $cmd
    eval $cmd 
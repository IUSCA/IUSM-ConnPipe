
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

echo "# ==========================================="
echo "# 1. Slice Time Acquisition Correction"
echo "# ==========================================="

if (( $(echo "${TR} > $configs_EPI_minTR" |bc -l) )); then

    if [[ -e "${EPIpath}/0_epi_unwarped.nii.gz" ]]; then  
        fileIn="${EPIpath}/0_epi_unwarped.nii.gz"
        log "Processing: 0_epi_unwarped.nii.gz"
    else
        fileIn=`ls ${EPIpath_raw}/*rest.nii*`
        if [[ -e "${fileIn}" ]]; then          
            log "Processing: raw nifti"
        else
            log "WARNIGN file 0_epi not found. Exiting..."   
            exit 1
        fi 
    fi 

    fileOut="${EPIpath}/0_epi.nii.gz"
    cmd="fslreorient2std ${fileIn} ${fileOut}"
    log $cmd 
    eval $cmd  

    fileRef="${EPIpath}/slicetimes_frac.txt"
    fileOut="${EPIpath}/1_epi.nii.gz"

    echo "TR --> ${TR}"
    echo "slice_ord --> ${slice_ord}"
    echo "slice_rev --> ${slice_rev}"

    if [[ ${slice_ord} -eq 2 ]] || [[ ${configs_EPI_UseTcustom} -eq 1 ]]; then  # Use custom interleave timing file

        cmd="slicetimer -i ${fileIn} -o ${fileOut} -r ${TR} --tcustom=${fileRef}"

    elif  [[ ${slice_ord} -eq 1 ]] && [[ ${configs_EPI_UseTcustom} -ne 1 ]]; then #Sequential acquisition

        if [[ ${slice_rev} -eq 0 ]]; then 
            cmd="slicetimer -i ${fileIn} -o ${fileOut} -r ${TR}"
        elif [[ ${slice_rev} -eq 1 ]]; then 
            cmd="slicetimer -i ${fileIn} -o ${fileOut} -r ${TR} --down"
        fi 

    elif [[ ${slice_ord} -eq 0 ]] && [[ ${configs_EPI_UseTcustom} -ne 1 ]]; then   # Interleaved acquisition
        
        if [[ ${slice_rev} -eq "0" ]]; then 
            cmd="slicetimer -i ${fileIn} -o ${fileOut} -r ${TR} --odd"
        elif [[ ${slice_rev} -eq "1" ]]; then 
            cmd="slicetimer -i ${fileIn} -o ${fileOut} -r ${TR} --odd --down"
        fi 
    fi 

    log $cmd
    eval $cmd 

else

    log "WARNING TR=${TR} is less than user specified minTR=${configs_EPI_minTR}"
    log "Skipping slice time correction"
fi

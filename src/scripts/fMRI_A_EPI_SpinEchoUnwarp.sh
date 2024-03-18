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

echo "# =================================="
echo "# 0. Spin Echo Field Map Correction"
echo "# =================================="

# Look for raw fieldmap directory (exported from main file)
if [[ -d "$FMAPpath_raw" ]]; then 
    ## Path to raw data
    FMAPpath="${path2ses}/fmap"
    if [[ ! -d "${FMAPpath}" ]]; then
        mkdir -p ${FMAPpath}
    fi
else
    log "No raw fieldmap directory: ${FMAPpath_raw}"
    exit 1
fi 


if ${flags_EPI_RunTopup}; then

    # Lets find the json files in the fmap directory 
    json_files=$(find "$FMAPpath_raw" -type f -name "*.json")
    intfTag=$(basename ${EPIfile})    #"${EPIfile#*raw/}" # epi file name so it can be matched to the intended for tag
    echo "intfTag  ${intfTag}"

    # Looping through the files
    for jsf in $json_files; do
        log "Json file: ${jsf}"
        # Now lets see if we can find the session being processed as intended for
        if grep -q "${intfTag}" "${jsf}"; then
            # if file name match (presumably under the intended for tag cause where else would it be)
            # check endoding direction
            log --no-datetime "Matched intended for tag found."
            PE=`cat ${jsf} | ${EXEDIR}/src/func/jq-linux64 ."PhaseEncodingDirection"`
            PE="${PE#?}"
            PE="${PE%?}"
            log --no-datetime "Phase Encoding: ${PE}"
            if [[ $PE == "j" ]]; then
                fileInPA="${jsf::-4}nii.gz"
                dim4PA=`fslnvols "${fileInPA}"` 
                log --no-datetime "Intended for PA fmap found (${dim4PA} volumes): ${fileInPA}"
            elif [[ "$PE" == "j-" ]]; then
                fileInAP="${jsf::-4}nii.gz"
                dim4AP=`fslnvols "${fileInAP}"`
                log --no-datetime "Intended for AP fmap found (${dim4AP} volumes): ${fileInAP}" 
            else
                log "Unknown Phase Encoding: ${PE}"
            fi
        else
            log "Not a match: ${jsf}"
        fi
    done

    if [ -f "${fileInAP}" ] && [ -f "${fileInPA}" ]; then # do both files exist
        if [ "$dim4AP" -eq "$dim4PA" ]; then # do they have the same number of volumes

            log "Concatenate the AP then PA into single 4D image"
                    
            # Concatenate the AP then PA into single 4D image
            fileOut="${FMAPpath}/func_sefield.nii.gz"
            if [ -e "${fileOut}" ]; then
                cmd="rm -fr ${fileOut}"
                log --no-datetime $cmd
                eval $cmd 
            fi 

            cmd="fslmerge -tr ${fileOut} ${fileInAP} ${fileInPA} ${TR}"
            log $cmd
            eval $cmd                 

            log "Generate acqparams file"
            echo "EPI_TotalReadoutTime -- ${EPI_TotalReadoutTime}"

            APstr=`echo -e '0 \t -1 \t  0 \t' ${EPI_TotalReadoutTime}`   
            PAstr=`echo -e '0 \t 1 \t  0 \t' ${EPI_TotalReadoutTime}`

            cmd="fslnvols ${fileOut}"
            log --no-datetime $cmd
            d4vol=`$cmd`
            echo "d4vol is $d4vol"

            SEnumMaps=$dim4AP

            acqparams="${FMAPpath}/func_acqparams.txt"
            if [[ -e ${acqparams} ]]; then
                echo "removing ${acqparams}"
                cmd="rm ${acqparams}"
                log $cmd
                eval $cmd
            fi 

            for ((k=0; k<${SEnumMaps}; k++)); do
                echo ${APstr} >> ${acqparams}
            done
            for ((k=0; k<${SEnumMaps}; k++)); do
                echo ${PAstr} >> ${acqparams}
            done

            fileIn="${FMAPpath}/func_sefield.nii.gz"

            # Generate (topup) and apply (applytopup) spin echo field map correction to 0_epi image.

            if [[ -e "${fileIn}" ]] && [[ -e ${acqparams} ]]; then
                fileOutName="${FMAPpath}/func_topup_results"
                fileOutField="${FMAPpath}/func_topup_field"
                fileOutUnwarped="${FMAPpath}/func_topup_unwarped"
                    
                log "topup: Starting topup on func_sefiled.nii.gz  --  This might take a wile... "
                cmd="topup --imain=${fileIn} \
                --datain=${acqparams} \
                --out=${fileOutName} \
                --fout=${fileOutField} \
                --iout=${fileOutUnwarped}"
                log $cmd
                eval $cmd 
                echo $?

                if [[ ! -e "${fileOutUnwarped}.nii.gz" ]]; then  # check that topup has been completed
                    log "ERROR Topup output not created. Exiting... "
                    exit 1
                fi
            else 
                log " WARNING ${fileIn} or ${acqparams} are missing. topup not started"
                exit 1
            fi
        else
            log "AP and PA maps contain unequal number of volumes. Check that fmaps are correct."
            exit 1
        fi
    else
        log "WARNING fileInAP and/or fileInPA files not found. Exiting..."
        exit 1 
    fi
else
    log "flags_EPI_RunTopup=false. Field map estimation will be skipped."
fi

acqparams="${FMAPpath}/func_acqparams.txt"
fileOutName="${FMAPpath}/func_topup_results"
fileOutCoefName="${fileOutName}_fieldcoef.nii.gz"

log "flags_EPI_RunTopup=false. Checking for existing topup output for applytopup..."
if [[ -f "${EPIfile}" ]] && [[ -f "${acqparams}" ]] && [[ -f "${fileOutCoefName}" ]]; then 

    fileOut="${EPIrun_out}/0_epi_unwarped.nii.gz"

    log "applytopup -- starting applytopup on 0_epi.nii.gz"

    cmd="applytopup --imain=${EPIfile} \
    --datain=${acqparams} \
    --inindex=1 \
    --topup=${fileOutName} \
    --out=${fileOut} --method=jac"

    log --no-datetime $cmd 
    eval $cmd 
    exitcode=$?

    if [[ $exitcode -eq 0 ]]; then
        log "- -------------EPI volume unwarping completed---------------"
    fi

else
    log "APPYTOPUP FAILED: MISSING AT LEAST ONE OF THE INPUT FILES."
    exit 1 
fi
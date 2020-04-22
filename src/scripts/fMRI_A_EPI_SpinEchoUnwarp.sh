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
    echo "# 0. Field Map Correction"
    echo "# =================================="

    # set up direcotry paths
    path_EPI_SEFM="${EPIpath}/${configs_sefmFolder}"
    path_EPI_APdcm="${path_EPI_SEFM}/${configs_APdcm}"
    echo "${path_EPI_APdcm}"
    path_EPI_PAdcm="${path_EPI_SEFM}/${configs_PAdcm}"
    echo "${path_EPI_PAdcm}"
    path_EPI_GREmagdcm="${path_EPI_SEFM}/${configs_GREmagdcm}"
    path_EPI_GREphasedcm="${path_EPI_SEFM}/${configs_GREphasedcm}"

    if [[ -d ${path_EPI_SEFM} ]]; then

        fileInAP="${path_EPI_SEFM}/AP.nii.gz"
        fileInPA="${path_EPI_SEFM}/PA.nii.gz"
        
        if [ -d "${path_EPI_APdcm}" ] && [ -d "${path_EPI_PAdcm}" ]; then

            fileNiiAP="AP"
            rm -fr ${path_EPI_SEFM}/${fileNiiAP}.nii*  # remove any existing .nii images
            log "rm -fr ${path_EPI_SEFM}/${fileNiiAP}.nii"
            # eval $cmd 

            # import AP fieldmaps
            fileLog="${path_EPI_APdcm}/dcm2niix_AP.log"
            cmd="dcm2niix -f $fileNiiAP -o ${path_EPI_SEFM} -v y -x y ${path_EPI_APdcm} > ${fileLog}"
            log $cmd
            eval $cmd

            fileNiiPA="PA"
            rm -fr ${path_EPI_SEFM}/${fileNiiPA}.nii*  # remove any existing .nii images
            log "rm -fr ${path_EPI_SEFM}/${fileNiiPA}.nii"
            #eval $cmd 

            # import PA fieldmaps
            fileLog="${path_EPI_PAdcm}/dcm2niix_PA.log"
            cmd="dcm2niix -f $fileNiiPA -o ${path_EPI_SEFM} -v y -x y ${path_EPI_PAdcm} > ${fileLog}"
            log $cmd
            eval $cmd      

            # gzip fieldmap volumes                  
            cmd="gzip -f ${path_EPI_SEFM}/AP.nii ${path_EPI_SEFM}/PA.nii"
            log $cmd
            eval $cmd 

            # Concatenate the AP then PA into single 4D image
            fileOut="${path_EPI_SEFM}/sefield.nii.gz"
            if [ -e "${fileOut}" ]; then
                cmd="rm -fr ${fileOut}"
                log $cmdn
                eval $cmd 
            fi 

            cmd="fslmerge -tr ${fileOut} ${fileInAP} ${fileInPA} ${TR}"
            log $cmd
            eval $cmd 

            # Generate an acqparams text file based on number of field maps.
            cmd="${EXEDIR}/src/scripts/get_readout.sh ${EPIpath}" 
            log $cmd
            EPI_SEreadOutTime=`$cmd`
            echo "EPI_SEreadOutTime -- ${EPI_SEreadOutTime}"

            APstr=`echo -e '0 \t -1 \t  0 \t' ${EPI_SEreadOutTime}`   
            PAstr=`echo -e '0 \t 1 \t  0 \t' ${EPI_SEreadOutTime}`

            cmd="fslinfo ${fileOut}"
            log $cmd
            out=`$cmd` 
            d4vol=$(echo $out | \
            awk '{split($0,a,"dim4"); {print a[2]}}' | \
            awk '{split($0,a," "); {print a[1]}}')
            exitcode=$?
            echo "d4vol is $d4vol"

            if [[ ${exitcode} -eq 0 ]]; then 

                if [[ $(bc <<< "$d4vol % 2 == 0") ]]; then
                    SEnumMaps=$(bc <<< "scale=0 ; $d4vol / 2")
                else
                    log "sefile.nii.gz file must contain even number of volumes. Exiting..."
                    exit 1
                fi                             
            else
                SEnumMaps=${configs_EPI_SEnumMaps}
            fi
            log "SEnumMaps: ${SEnumMaps}"

            acqparams="${path_EPI_SEFM}/acqparams.txt"
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

            # Generate (topup) and apply (applytopup) spin echo field map
            # correction to 0_epi image.

            fileIn="${path_EPI_SEFM}/sefield.nii.gz"
            if [[ -e "${fileIn}" ]] && [[ -e ${acqparams} ]]; then
                fileOutName="${path_EPI_SEFM}/topup_results"
                fileOutField="${path_EPI_SEFM}/topup_field"
                fileOutUnwarped="${path_EPI_SEFM}/topup_unwarped"


                if ${flags_EPI_RunTopup}; then
                    log "topup: Starting topup on sefiled.nii.gz  --  This might take a wile... "
                    cmd="topup --imain=${fileIn} \
                    --datain=${acqparams} \
                    --out=${fileOutName} \
                    --fout=${fileOutField} \
                    --iout=${fileOutUnwarped}"
                    log $cmd
                    eval $cmd 
                    echo $?
                fi 

                if [[ ! -e "${fileOutUnwarped}.nii.gz" ]]; then  # check that topup has been completed
                    log "WARNING Topup output not created. Exiting... "
                    exit 1
                fi

                fileIn="${EPIpath}/0_epi.nii.gz"
                if [[ -e "${fileIn}" ]]; then 

                    log "applytopup -- starting applytopup on 0_epi.nii.gz"
                    fileOut="${path_EPI_SEFM}/0_epi_unwarped.nii.gz"
                    cmd="applytopup --imain=${fileIn} \
                    --datain=${acqparams} \
                    --inindex=1 \
                    --topup=${fileOutName} \
                    --out=${fileOut} --method=jac"

                    log $cmd 
                    eval $cmd  
                else
                    log "WARNING 0_epi.nii.gz not found. Exiting..."
                    exit 1 
                fi

                if [[ -e "${fileOut}" ]]; then  
                    cmd="mv ${fileOut} ${EPIpath}/0_epi_unwarped.nii.gz"
                    log $cmd 
                    eval $cmd 
                    exitcode=$?

                    if [[ $exitcode -eq 0 ]]; then
                        log "- -------------EPI volume unwarping completed---------------"
                    fi

                fi 
            else 
                log " WARNING UNWARP/sefield.nii.gz or acqparams.txt are missing. topup not started"
                exit 1
            fi 

        elif [ -d "${path_EPI_GREmagdcm}" ] && [ -d "${path_EPI_GREphasedcm}" ]; then
            # identify dicoms 
            declare -a dicom_files
            while IFS= read -r -d $'\0' dicomfile; do 
                dicom_files+=( "$dicomfile" )
            done < <(find ${path_EPI_GREmagdcm} -iname "*.${configs_dcmFiles}" -print0 | sort -z)

            if [ ${#dicom_files[@]} -eq 0 ]; then 
                echo "No dicom (.${configs_dcmFiles}) images found."
                echo "Please specify the correct file extension of dicom files by setting the configs_dcmFiles flag in the config file"
                echo "Skipping further analysis"
                exit 1
            else
                # Extract TE1 and TE2 from the first image of Gradient Echo Magnitude Series
                # fsval image descrip would do the same but truncates TEs to a single digit!
                echo "There are ${#dicom_files[@]} dicom files in this EPI-series "
                dcm_file=${dicom_files[0]}
                cmd="dicom_hinfo -tag 0018,0081 ${path_EPI_GREmagdcm}/${dcm_file}"
                log $cmd
                out=`$cmd`
                TE1=`echo $out | awk -F' ' '{ print $2}'`
                echo "Header extracted TE is: ${TE1}" 
            fi

            ################################################################################
                        # Code missing here - need data with GRE field maps to test
            ################################################################################

        else 
            log "WARNING. UNWARP DICOMS folders do not exist. Field Map correction failed."
        fi 

    else
        log "WARNING ${path_EPI_SEFM} doesn't exist. Field map correction must be skipped."
    fi
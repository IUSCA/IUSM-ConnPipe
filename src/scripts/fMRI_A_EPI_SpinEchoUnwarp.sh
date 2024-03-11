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

    # set up direcotry paths
    if ! ${configs_EPI_multiSEfieldmaps}; then  # Assume single pair of SE fieldmaps within EPI folder
        echo "SINGLE SE FIELDMAP FOLDER ${EPIpath}/${configs_sefmFolder}"
        RD_path_EPI_SEFM="${RD_EPIpath}/${configs_sefmFolder}"
        path_EPI_SEFM="${EPIpath}/${configs_sefmFolder}"
    else  # Allows multiple UNWARP folders at the subject level (UNWARP1, UNWARP2,...)
        echo "MULTIPLE SE FIELDMAP FOLDERS"
        if ${configs_EPI_match}; then
            # match UNWARPi with EPIi
            echo "MATCH EPI AND UNWARP INDEX"
            RD_path_EPI_SEFM="${path2data}/${SUBJ}/${configs_sefmFolder}${EPInum}"
            path_EPI_SEFM="${path2derivs}/${SUBJ}/${configs_sefmFolder}${EPInum}"
        else
            # use single UNWARP foler (configs_sefmFolder) for all EPIi sessions
            echo "USING SINGLE ${configs_sefmFolder} FOR ALL EPI SESSIONS"
            RD_path_EPI_SEFM="${path2data}/${SUBJ}/${configs_sefmFolder}"
            path_EPI_SEFM="${path2derivs}/${SUBJ}/${configs_sefmFolder}"
        fi
    fi 

    echo "Raw Data FIELDMAP FOLDER: ${RD_path_EPI_SEFM}"
    echo "Derivatives FIELDMAP FOLDER: ${path_EPI_SEFM}"

    if [[ ! -d ${RD_path_EPI_SEFM} ]]; then
        log "WARNING ${RD_path_EPI_SEFM} doesn't exist. Field map correction must be skipped."
        exit 1
    fi

    if [[ ! -d "${path_EPI_SEFM}" ]]; then
        mkdir -p ${path_EPI_SEFM}
    fi  

    path_EPI_APdcm="${RD_path_EPI_SEFM}/${configs_APdcm}"
    echo "APdcm path is ${path_EPI_APdcm}"
    path_EPI_PAdcm="${RD_path_EPI_SEFM}/${configs_PAdcm}"
    echo "PAdcm path is ${path_EPI_PAdcm}"

    fileInAP="${path_EPI_SEFM}/AP.nii.gz"
    fileInPA="${path_EPI_SEFM}/PA.nii.gz"

    if [ ! -f "${fileInAP}" ] && [ ! -f "${fileInPA}" ]; then

        log "IMPORT AP and PA fieldmaps from DICOM"

        fileNiiAP="AP"
        rm -fr ${path_EPI_SEFM}/${fileNiiAP}.nii*  # remove any existing .nii images
        log "rm -fr ${path_EPI_SEFM}/${fileNiiAP}.nii"
        

        # import AP fieldmaps
        fileLog="${path_EPI_SEFM}/dcm2niix_AP.log"
        cmd="dcm2niix -f $fileNiiAP -o ${path_EPI_SEFM} -v y -x y ${path_EPI_APdcm} > ${fileLog}"
        log $cmd
        eval $cmd

        fileNiiPA="PA"
        rm -fr ${path_EPI_SEFM}/${fileNiiPA}.nii*  # remove any existing .nii images
        log "rm -fr ${path_EPI_SEFM}/${fileNiiPA}.nii"

        # import PA fieldmaps
        fileLog="${path_EPI_SEFM}/dcm2niix_PA.log"
        cmd="dcm2niix -f $fileNiiPA -o ${path_EPI_SEFM} -v y -x y ${path_EPI_PAdcm} > ${fileLog}"
        log $cmd
        eval $cmd      

        # gzip fieldmap volumes                  
        cmd="gzip -f ${path_EPI_SEFM}/AP.nii ${path_EPI_SEFM}/PA.nii"
        log $cmd
        eval $cmd 

    fi

    ## check to see if FM needs to be re-calculated
    #  If FM has been calculated && we are using a single UNWARP folder
    if ${first_FMcalc} && ! ${configs_EPI_match}; then
        log "Skipping Re-Calculating FM; topup has already been run"
        FMcalc=false
    else 
        log "Calculating FM and running topup"
        FMcalc=true
    fi

    
    if [ -f "${fileInAP}" ] && [ -f "${fileInPA}" ]; then

        if ${FMcalc}; then

            log "Concatenate the AP then PA into single 4D image"
            
            # Concatenate the AP then PA into single 4D image
            fileOut="${path_EPI_SEFM}/sefield.nii.gz"
            if [ -e "${fileOut}" ]; then
                cmd="rm -fr ${fileOut}"
                log $cmd
                eval $cmd 
            fi 

            cmd="fslmerge -tr ${fileOut} ${fileInAP} ${fileInPA} ${TR}"
            log $cmd
            eval $cmd                 

            # Generate an acqparams text file based on number of field maps.
            echo "EPI_SEreadOutTime -- ${EPI_SEreadOutTime}"

            APstr=`echo -e '0 \t -1 \t  0 \t' ${EPI_SEreadOutTime}`   
            PAstr=`echo -e '0 \t 1 \t  0 \t' ${EPI_SEreadOutTime}`

            cmd="fslinfo ${fileOut}"
            log $cmd
            out=`$cmd` 
            d4vol=$(echo $out | \
            awk '{split($0,a,"dim4"); {print a[2]}}' | \
            awk '{split($0,a," "); {print a[1]}}')   
            exitcode=$?   # extract number of volumes from sefield.nii.gz
            echo "d4vol is $d4vol"

            if [[ ${exitcode} -eq 0 ]]; then 

                if [[ $(bc <<< "$d4vol % 2 == 0") ]]; then
                    SEnumMaps=$(bc <<< "scale=0 ; $d4vol / 2")   #convert number of volumes to a number
                    log "SEnumMaps extracted from sefield.nii.gz: ${SEnumMaps}"
                else
                    log "sefile.nii.gz file must contain even number of volumes. Exiting..."
                    exit 1
                fi                             
            else
                SEnumMaps=${configs_EPI_SEnumMaps}  #  trust the user input if SEnumMaps failed
                log "SEnumMaps from user-specified parameter: ${SEnumMaps}"
            fi            

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
        else
            log "Skipping re-calculation of acqparams.txt"
            acqparams="${path_EPI_SEFM}/acqparams.txt"
        fi
    else
        log "WARNING ${fileInAP} and/or ${fileInPA} files not found. Exiting..."
        exit 1 
    fi 

    # Generate (topup) and apply (applytopup) spin echo field map
    # correction to 0_epi image.
    if ${flags_EPI_RunTopup}; then

        fileIn="${path_EPI_SEFM}/sefield.nii.gz"

        if [[ -e "${fileIn}" ]] && [[ -e ${acqparams} ]]; then

            fileOutName="${path_EPI_SEFM}/topup_results"
            fileOutField="${path_EPI_SEFM}/topup_field"
            fileOutUnwarped="${path_EPI_SEFM}/topup_unwarped"
        
            # only calculate params and Field Maps once if using single UNWARP folder
            if ${FMcalc}; then
                log "topup: Starting topup on sefiled.nii.gz  --  This might take a wile... "
                cmd="topup --imain=${fileIn} \
                --datain=${acqparams} \
                --out=${fileOutName} \
                --fout=${fileOutField} \
                --iout=${fileOutUnwarped}"
                log $cmd
                eval $cmd 
                echo $?
            else
                log "Topup has already been run for this session"
            fi

            if [[ ! -e "${fileOutUnwarped}.nii.gz" ]]; then  # check that topup has been completed
                log "ERROR Topup output not created. Exiting... "
                exit 1
            fi

            fileIn="${EPIpath}/0_epi.nii.gz"
            acqparams="${path_EPI_SEFM}/acqparams.txt"
            fileOutName="${path_EPI_SEFM}/topup_results"
            fileOutCoefName="${fileOutName}_fieldcoef.nii.gz"

            if [[ -f "${fileIn}" ]] && [[ -f "${acqparams}" ]] && [[ -f "${fileOutCoefName}" ]]; then 

                fileOut="${path_EPI_SEFM}/0_epi_unwarped.nii.gz"

                log "applytopup -- starting applytopup on 0_epi.nii.gz"

                cmd="applytopup --imain=${fileIn} \
                --datain=${acqparams} \
                --inindex=1 \
                --topup=${fileOutName} \
                --out=${fileOut} --method=jac"

                log $cmd 
                eval $cmd  
            else
                log "WARNING 0_epi.nii.gz not found or topup outputs do not exist. Exiting..."
                exit 1 
            fi

            if [[ -e "${fileOut}" ]]; then  
                cmd="mv ${fileOut} ${EPIpath}/0_epi_unwarped.nii.gz"
                log $cmd 
                eval $cmd 
                exitcode=$?

                if [[ $exitcode -eq 0 ]]; then
                    log "- -------------EPI volume unwarping completed---------------"
                else
                    log "WARNING - unable to move ${fileOut} to ${EPIpath}/0_epi_unwarped.nii.gz"
                fi

            fi                  
        else 
            log " WARNING ${fileIn} or ${acqparams} are missing. topup not started"
            exit 1
        fi 
    fi 




    
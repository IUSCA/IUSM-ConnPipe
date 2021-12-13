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
    echo "# 0. Gradient echo field maps"
    echo "# =================================="

    export GREFMpath="${path2data}/${SUBJ}/${configs_grefmFolder}"

    # Gradient echo field maps (directory at the same level as T1 and EPI)
    if [[ ! -d "${GREFMpath}" ]]; then  # Assume single pair of SE fieldmaps within EPI folder
        log "WARNING ${GREFMpath} des not exist. Field map correction will be skipped"
    else  
        path_GREmagdcm="${GREFMpath}/${configs_GREmagdcm}"
        path_GREphasedcm="${GREFMpath}/${configs_GREphasedcm}"

        fileNm1=${configs_Mag_file}
        fileNm2="${configs_Phase_file}"
        filePhaseMapNm="gre_fieldmap_phasediff"
            
        log "EPI session number: ${EPInum}"

        if [[ -z "${EPInum}" ]] || [[ ${EPInum} -le ${configs_EPI_skipFMcalc4EPI} ]]; then

            log "GREmap4EPI: ${EPInum} -le ${configs_EPI_skipFMcalc4EPI}"

            if ${configs_use_DICOMS} && [ -d "${path_GREmagdcm}" ] && [ -d "${path_GREphasedcm}" ]; then

                log "GREFM extracting from DICOM files"

                # identify dicoms 
                declare -a dicom_files
                while IFS= read -r -d $'\0' dicomfile; do 
                    dicom_files+=( "$dicomfile" )
                done < <(find ${path_GREmagdcm} -iname "*.${configs_dcmFiles}" -print0 | sort -z)

                if [ ${#dicom_files[@]} -eq 0 ]; then 
                    echo "No dicom (.${configs_dcmFiles}) images found."
                    echo "Please specify the correct file extension of dicom files by setting the configs_dcmFiles flag in the config file"
                    echo "Skipping further analysis"
                    exit 1
                else
                    # Extract TE1 and TE2 from the first image of Gradient Echo Magnitude Series
                    # fsval image descrip would do the same but truncates TEs to a single digit!
                    echo "There are ${#dicom_files[@]} dicom files in ${path_GREmagdcm} "
                    
                    dcm_file=${dicom_files[0]}
                    cmd="dicom_hinfo -tag 0018,0081 ${dcm_file}"
                    log $cmd
                    out=`$cmd`
                    TE1=`echo $out | awk -F' ' '{ print $2}'`
                    echo "Header extracted TE1 is: ${TE1}" 

                    dcm_file=${dicom_files[1]}
                    cmd="dicom_hinfo -tag 0018,0081 ${dcm_file}"
                    log $cmd
                    out=`$cmd`
                    TE2=`echo $out | awk -F' ' '{ print $2}'`
                    echo "Header extracted TE2 is: ${TE2}"

                    DeltaTE=$(bc <<< "scale=0 ; ${TE2} - ${TE1}")
                    log "Calculated DeltaTE is ${DeltaTE}"
                fi

                fileMag1="${GREFMpath}/${fileNm1}_e1.nii"
                if [[ -f ${fileMag1} ]]; then
                    cmd="rm ${fileMag1}"
                    log $cmd
                    eval $cmd
                fi

                fileMag2="${GREFMpath}/${fileNm1}_e2.nii"
                if [[ -f ${fileMag2} ]]; then
                    cmd="rm ${fileMag2}"
                    log $cmd
                    eval $cmd
                fi

                # dicom import
                fileLog="${path_GREmagdcm}/dcm2niix.log"
                cmd="dcm2niix -f $fileNm1 -o ${GREFMpath} -v y -x y ${path_GREmagdcm} > ${fileLog}"
                log $cmd
                eval $cmd

                # remove any existing file
                filePhaseMap="${GREFMpath}/${fileNm2}_e2_ph.nii"
                if [[ -f ${filePhaseMap} ]]; then
                    cmd="rm ${filePhaseMap}"
                    log $cmd
                    eval $cmd
                fi

                # dicom import
                fileLog="${path_GREphasedcm}/dcm2niix.log"
                cmd="dcm2niix -f $fileNm2 -o ${GREFMpath} -v y -x y ${path_GREphasedcm} > ${fileLog}"
                log $cmd
                eval $cmd 

            elif ! ${configs_use_DICOMS} && ${configs_extract_twoMags} && [ -f "${GREFMpath}/${fileNm1}.nii.gz" ]; then 

                log "GREFM Extracting Mag1 and Mag2 from ${GREFMpath}/${fileNm1}"

                fileMag1="${GREFMpath}/${fileNm1}_0000.nii.gz"
                fileMag2="${GREFMpath}/${fileNm1}_0001.nii.gz"

                # split 3D volumes in Mag image, corresponding to Mag1 and Mag2
                cmd="fslsplit ${GREFMpath}/${fileNm1}.nii.gz ${GREFMpath}/${fileNm1}_ -t"
                log $cmd
                eval $cmd 

            elif ! ${configs_use_DICOMS} && ! ${configs_extract_twoMags} && \ 
                 [ -f "${GREFMpath}/${configs_Mag1}" ] && [ -f "${GREFMpath}/${configs_Mag2}" ]; then 

                log "GREFM Mag1 and Mag2 provided by user"

                fileMag1="${GREFMpath}/${configs_Mag1}"
                fileMag2="${GREFMpath}/${configs_Mag2}"


            else 
                log "WARNING UNWARP DICOMS folders or filedmap magnitude nii images do not exist. Field Map correction failed. Exiting..."
                exit 1

            fi

            echo "FINDING ${fileMag1}"
            echo "FINDING ${fileMag2}"

            if [[ -f ${fileMag1} ]] && [[ -f ${fileMag2} ]]; then

                fileMagAvg="${GREFMpath}/gre_fieldmap_magAVG"
                cmd="fslmaths ${fileMag1} -add ${fileMag2} -div 2 ${fileMagAvg}"
                log $cmd
                eval $cmd

                fileIn="${fileMagAvg}.nii.gz"
                fileMagBrain="${GREFMpath}/gre_fieldmap_magAVG_brain"

                cmd="bet ${fileIn} ${fileMagBrain} \
                    -f ${configs_EPI_GREbetf} \
                    -g ${configs_EPI_GREbetg} -m"
                log $cmd
                eval $cmd 

                fileFMap="${GREFMpath}/${fileNm2}_rads_prepared"

                if ${configs_use_DICOMS} && ${configs_fsl_prepare_fieldmap}; then
                    # Prepare phase map
                    # fsl_prepare_fieldmap <scanner> <phase_image> <magnitude_image> <out_image> <deltaTE (in ms)>
                    cmd="fsl_prepare_fieldmap ${scanner} ${GREFMpath}/${fileNm2} ${fileMagBrain} ${fileFMap} ${DeltaTE}"
                    log $cmd
                    eval $cmd
                fi 

                if ${configs_convert2radss}; then 
                  # phasemap needs to be converted from Hz to Rad/s and masked 

                    cmd="fslmaths ${GREFMpath}/${fileNm2}.nii.gz -mul 6.28 ${fileFMap}"
                    log $cmd
                    eval $cmd

                    cmd="fslmaths ${fileFMap}.nii.gz \
                        -mul ${fileMagBrain}_mask.nii.gz ${fileFMap}.nii.gz" 
                    log $cmd
                    eval $cmd
                fi                   

                # Now run fugue (-s 3 : apply Gaussian smoothing of sigma = 3mm -- smoothing 
                fileFMapIn="${fileFMap}.nii.gz"

                if [ -f ${fileFMapIn} ]; then

                    if ${configs_EPI_GREdespike}; then
                        fileFMapRads="${GREFMpath}/fm_rads_brain_sm${configs_EPI_GREsmooth}_m_ds"
                        cmd="fugue --loadfmap=${fileFMapIn} \
                        -s ${configs_EPI_GREsmooth} \
                        -m --despike \
                        --savefmap=${fileFMapRads}"
                    else
                        fileFMapRads="${GREFMpath}/fm_rads_brain_sm${configs_EPI_GREsmooth}_m"
                        cmd="fugue --loadfmap=${fileFMapIn} \
                        -s ${configs_EPI_GREsmooth} \
                        -m --savefmap=${fileFMapRads}"                    

                    fi

                    log $cmd
                    eval $cmd 

                    fileFMapRadsOut="${fileFMapRads}.nii.gz"
                    if [[ -f "${fileFMapRadsOut}" ]]; then
                        log "Fugue successfully created fm_rads_brain field map"
                    else
                        log "WARNING ${fileFMapRadOut} not created: fugue failed. Exiting..."
                        exit 1
                    fi

                else 
                    "WARNING ${fileFMapIn} not found. Exiting..."
                    exit 1
                fi

            else 
                log "WARNING Field Map images not found. Exiting..."
                exit 1
            fi 

        elif [[ ${EPInum} -gt ${configs_EPI_skipFMcalc4EPI} ]]; then

            log "GREmap4EPI: ${EPInum} -gt ${configs_EPI_skipFMcalc4EPI}"

                if ${configs_EPI_GREdespike}; then

                    fileFMapRadsOut="${GREFMpath}/fm_rads_brain_sm${configs_EPI_GREsmooth}_m_ds.nii.gz"

                else
                    fileFMapRadsOut="${GREFMpath}/fm_rads_brain_sm${configs_EPI_GREsmooth}_m.nii.gz"      

                fi   

                if [[ -f "${fileFMapRadsOut}" ]]; then
                    log "Using existing ${fileFMapRadsOut} field map"
                else
                    log "WARNING ${fileFMapRadsOut} does not exist. Exiting..."
                    exit 1
                fi          

        else
            log "WARNING fm_rads_brain does not exist or GRE map calculation skipped!"
            exit 1
        fi 

        fileIn="${EPIpath}/0_epi.nii.gz"

        if [[ -f "${fileIn}" ]]; then

            fileOut="${EPIpath}/0_epi_unwarped"

            cmd="fugue -i ${fileIn} \
            --dwell=${EPI_EffectiveEchoSpacing} \
            --loadfmap=${fileFMapRadsOut} \
            --unwarpdir=y- -u ${fileOut}"

            log "fugue Applying fugue to unwarp 0_epi.nii.gz."
            log $cmd
            eval $cmd

            if [[  -f "${fileOut}.nii.gz" ]]; then
                log "fugue o_epi_unwarped.nii.gz successfully created"
            else
                log "WARNING fugue unwarping failed. Exiting..."
                exit 1
            fi 


        else 
            log "WARNING  0_epi.nii.gz not found. Exiting... "
            exit 1

        fi 


    fi 




 







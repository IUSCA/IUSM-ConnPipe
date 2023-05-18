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
    log "FIELDMAP FOLDER: ${GREFMpath}" 

    # Gradient echo field maps (directory at the same level as T1 and EPI)
    if [[ ! -d "${GREFMpath}" ]]; then  
        log "WARNING ${GREFMpath} des not exist. Field map correction will be skipped"
    else  
        path_GREmagdcm="${GREFMpath}/${configs_GREmagdcm}"
        path_GREphasedcm="${GREFMpath}/${configs_GREphasedcm}"

        log "path_GREmagdcm FOLDER: ${path_GREmagdcm}" 
        log "path_GREphasedcm FOLDER: ${path_GREphasedcm}" 

        filePhaseMapNm="gre_fieldmap_phasediff"

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
                
                dcm_file=${dicom_files[2]}
                cmd="dicom_hinfo -tag 0018,0081 ${dcm_file}"
                log $cmd
                out=`$cmd`
                TE1=`echo $out | awk -F' ' '{ print $2}'`
                echo "Header extracted TE1 is: ${TE1}" 

                dcm_file=${dicom_files[0]}
                cmd="dicom_hinfo -tag 0018,0081 ${dcm_file}"
                log $cmd
                out=`$cmd`
                TE2=`echo $out | awk -F' ' '{ print $2}'`
                echo "Header extracted TE2 is: ${TE2}"

                DeltaTE=$(bc <<< "scale=0 ; ${TE2} - ${TE1}")
                log "Calculated DeltaTE is ${DeltaTE}"
            fi

            fileMag1="${GREFMpath}/${configs_Mag_file}_e1.nii"
            if [[ -f ${fileMag1} ]]; then
                cmd="rm ${fileMag1}"
                log $cmd
                eval $cmd
            fi

            fileMag2="${GREFMpath}/${configs_Mag_file}_e2.nii"
            if [[ -f ${fileMag2} ]]; then
                cmd="rm ${fileMag2}"
                log $cmd
                eval $cmd
            fi

            # dicom import
            fileLog="${path_GREmagdcm}/dcm2niix.log"
            cmd="dcm2niix -f ${configs_Mag_file} -o ${GREFMpath} \
                -v y -x y ${path_GREmagdcm} > ${fileLog}"
            log $cmd
            eval $cmd

            # remove any existing phase-map files
            rm ${GREFMpath}/${configs_Phase_file}_e2_ph*


            # dicom import
            fileLog="${path_GREphasedcm}/dcm2niix.log"
            cmd="dcm2niix -f ${configs_Phase_file} -o ${GREFMpath} \
                -v y -x y ${path_GREphasedcm} > ${fileLog}"
            log $cmd
            eval $cmd 

            # identify full name of phasemap file with echoNum
            if [[ -f "${GREFMpath}/${configs_Phase_file}_e2_ph.nii" ]]; then
                export configs_Phase_file="${configs_Phase_file}_e2_ph"
            elif [[ -f "${GREFMpath}/${configs_Phase_file}_e1_ph.nii" ]]; then
                export configs_Phase_file="${configs_Phase_file}_e1_ph"
            else
                log "WARNING ${GREFMpath}/${configs_Phase_file} not found. Exiting..."
                exit 1   
            fi

            log "Phasemap file name is ${configs_Phase_file}"

        elif ! ${configs_use_DICOMS} && ${configs_extract_twoMags} \
            && [ -f "${GREFMpath}/${configs_Mag_file}.nii.gz" ]; then 

            log "GREFM Extracting Mag1 and Mag2 from ${GREFMpath}/${configs_Mag_file}"

            # split 3D volumes in Mag image, corresponding to Mag1 and Mag2
            cmd="fslsplit ${GREFMpath}/${configs_Mag_file}.nii.gz \
                ${GREFMpath}/${configs_Mag_file}_ -t"
            log $cmd
            eval $cmd 

            fileMag1="${GREFMpath}/${configs_Mag1}.nii.gz"
            fileMag2="${GREFMpath}/${configs_Mag2}.nii.gz"                

        elif ! ${configs_use_DICOMS} && ! ${configs_extract_twoMags} && [ -f "${GREFMpath}/${configs_Mag1}" ] && [ -f "${GREFMpath}/${configs_Mag2}" ]; then 

            log "GREFM Mag1 and Mag2 provided by user"

            fileMag1="${GREFMpath}/${configs_Mag1}"
            fileMag2="${GREFMpath}/${configs_Mag2}"


        else 
            log "WARNING UNWARP DICOMS folders or filedmap magnitude \
                nii images do not exist. Field Map correction failed. Exiting..."
            exit 1

        fi

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

            # gzip fieldmap volumes 
            if [[ -f "${GREFMpath}/${configs_Phase_file}.nii" ]]; then
                cmd="gzip -f ${GREFMpath}/${configs_Phase_file}.nii"
                log $cmd
                eval $cmd 
            fi 

            fileFMap="${GREFMpath}/${configs_Phase_file}.nii.gz"

            if ${configs_use_DICOMS} && ${configs_fsl_prepare_fieldmap}; then
                # Prepare phase map
                # fsl_prepare_fieldmap <scanner> <phase_image> 
                    #<magnitude_image> <out_image> <deltaTE (in ms)>
                    # 
                fileFMap="${GREFMpath}/${configs_Phase_file}_rads_prepared.nii.gz"
                
                cmd="fsl_prepare_fieldmap ${scanner} \
                    ${GREFMpath}/${configs_Phase_file} \
                    ${fileMagBrain} ${fileFMap} ${DeltaTE}"
                log $cmd
                eval $cmd
            fi 

            if ${configs_convert2radss}; then 
                # phasemap needs to be converted from Hz to Rad/s and masked 

                cmd="fslmaths ${GREFMpath}/${configs_Phase_file}.nii.gz -mul 6.28 ${fileFMap}"
                log $cmd
                eval $cmd

                cmd="fslmaths ${fileFMap} \
                    -mul ${fileMagBrain}_mask.nii.gz ${fileFMap}" 
                log $cmd
                eval $cmd
            fi                   

            # Now run fugue (-s 3 : apply Gaussian smoothing of sigma = 3mm -- smoothing 
            if [ -f ${fileFMap} ]; then

                if ${configs_EPI_GREdespike}; then
                    fileFMapRads="${GREFMpath}/fm_rads_brain_sm${configs_EPI_GREsmooth}_m_ds"
                    cmd="fugue --loadfmap=${fileFMap} \
                    -s ${configs_EPI_GREsmooth} \
                    -m --despike \
                    --savefmap=${fileFMapRads}"
                else
                    fileFMapRads="${GREFMpath}/fm_rads_brain_sm${configs_EPI_GREsmooth}_m"
                    cmd="fugue --loadfmap=${fileFMap} \
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
                "WARNING ${fileFMap} not found. Exiting..."
                exit 1
            fi

        else 
            log "WARNING Field Map images not found. Exiting..."
            exit 1
        fi 

    # elif [[ ${EPInum} -gt ${configs_EPI_skipFMcalc4EPI} ]]; then

        # log "GREmap4EPI: ${EPInum} -gt ${configs_EPI_skipFMcalc4EPI}"

        #     if ${configs_EPI_GREdespike}; then

        #         fileFMapRadsOut="${GREFMpath}/fm_rads_brain_sm${configs_EPI_GREsmooth}_m_ds.nii.gz"

        #     else
        #         fileFMapRadsOut="${GREFMpath}/fm_rads_brain_sm${configs_EPI_GREsmooth}_m.nii.gz"      

        #     fi   

        #     if [[ -f "${fileFMapRadsOut}" ]]; then
        #         log "Using existing ${fileFMapRadsOut} field map"
        #     else
        #         log "WARNING ${fileFMapRadsOut} does not exist. Exiting..."
        #         exit 1
        #     fi          



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




 







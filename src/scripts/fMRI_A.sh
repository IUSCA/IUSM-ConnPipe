
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


log "fMRI_A"

# Generate list of EPI scan directories
declare -a epiList
while IFS= read -r -d $'\0' REPLY; do 
    epiList+=( "$REPLY" )
done < <(find ${path2data}/${SUBJ} -maxdepth 1 -type d -iname "*${configs_epiFolder}*" -print0)


if [ ${#epiList[@]} -eq 0 ]; then 
    echo "No EPI directories found for subject $SUBJ. Check consistency of naming convention."
    exit 1
else
    echo "There are ${#epiList[@]} EPI-series "
fi

for ((i=0; i<${#epiList[@]}; i++)); do

    if [[ ! -d "${epiList[$i]}" ]]; then
        echo "${epiList[$i]} directory not found"
    else
        # Operating on the scans set in configs
        if [ $((i+1)) -ge "${configs_EPI_epiMin}" ] \
            && [ $((i+1)) -le "${configs_EPI_epiMax}" ]; then

            export EPIpath="${epiList[$i]}"
            log "fMRI_A on subject ${SUBJ}"
            log "EPI-series ${EPIpath}"

            ## functional connectivity

            # ### Convert dcm2nii
            if ${flags_EPI_dcm2niix}; then

                echo "=================================="
                echo "0. Dicom to NIFTI conversion"
                echo "=================================="

                path_EPIdcm=${EPIpath}/${configs_dcmFolder}
                echo "path_EPIdcm is -- ${path_EPIdcm}"
                epifile="0_epi"
                fileNii="${EPIpath}/${epifile}.nii"
                fileNiigz="${EPIpath}/${epifile}.nii.gz"

                if [ -e ${fileNii} ] || [ -e ${fileNiigz} ]; then                 
                    cmd="rm -rf ${fileNii}*"
                    log $cmd
                    rm -rf ${fileNii}* 
                fi 

                # import dicoms
                fileLog="${EPIpath}/dcm2niix.log"
                cmd="dcm2niix -f ${epifile} -o ${EPIpath} -v y -x y ${path_EPIdcm} > ${fileLog}"
                log $cmd
                eval $cmd

                cmd="gzip -f ${EPIpath}/${epifile}.nii"
                log $cmd
                eval $cmd

                if [[ ! -e "${fileNiigz}" ]]; then
                    log "${fileNiigz} file not created. Exiting... "
                    exit 1
                fi                 
            else
                if [[ -f "${EPIpath}/0_param_dcm_hdr.sh" ]]; then
                    # echo "The next three lines should be uncommented but leave like this for now"
                    log "Sourcing parameters from ${EPIpath}/0_param_dcm_hdr.sh"
                    source ${EPIpath}/0_param_dcm_hdr.sh 
                    export flags_EPI_ReadHeaders=false
                else
                    log "File ${EPIpath}/0_param_dcm_hdr.sh not found; Exiting..."
                fi 
            fi

            #### Read info from the headers of the dicom fMRI volumes
            if ${flags_EPI_ReadHeaders}; then

                cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_ReadHeaders.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at fMRI_A_EPI_ReadHeaders. exiting."
                    exit 1
                fi  

                log "Sourcing parameters read from header and written to ${EPIpath}/0_param_dcm_hdr.sh"
                source ${EPIpath}/0_param_dcm_hdr.sh                
            fi


            if ${flags_EPI_SpinEchoUnwarp}; then 
            
                cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_SpinEchoUnwarp.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at fMRI_A_EPI_SpinEchoUnwarp. exiting."
                    exit 1
                fi
              
            fi 

            if ${flags_EPI_SliceTimingCorr}; then 

                cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_SliceTimingCorr.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at fMRI_A_EPI_SliceTimingCorr. exiting."
                    exit 1
                fi

            fi 


            if ${flags_EPI_MotionCorr}; then 

                cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_MotionCorr.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at fMRI_A_EPI_MotionCorr. exiting."
                    exit 1
                fi
            fi 


            if ${flags_EPI_RegT1}; then 

                cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_RegT1.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at flags_EPI_RegT1. exiting."
                    exit 1
                fi               
            fi 

            if ${flags_EPI_RegOthers}; then

                #source activate ${path2env}
                
                cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_RegOthers.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at fMRI_A_EPI_RegOthers. exiting."
                    exit 1
                fi  

                #source deactivate
            fi 


            if ${flags_EPI_IntNorm4D}; then

                cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_IntNorm4D.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at fMRI_A_EPI_IntNorm4D. exiting."
                    exit 1
                fi  
            fi            

            if ${flags_EPI_NuisanceReg}; then
                echo "# =========================================================="
                echo "# 5  Nuisance Regression. "
                echo "# =========================================================="

                if ${flags_NuisanceReg_AROMA}; then

                    #source activate ${path2env}

                    cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_AROMA.sh"
                    echo $cmd
                    eval $cmd
                    exitcode=$?

                    if [[ ${exitcode} -ne 0 ]] ; then
                        echoerr "problem at fMRI_A_EPI_AROMA. exiting."
                        exit 1
                    fi                
                    #source deactivate
                   
                elif ${flags_NuisanceReg_HeadParam}; then

                    cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_HeadMotionParam.sh"
                    echo $cmd
                    eval $cmd
                    exitcode=$?

                    if [[ ${exitcode} -ne 0 ]] ; then
                        echoerr "Problem at fMRI_A_EPI_HeadMotionParam. Exiting."
                        exit 1
                    fi  
                fi 
            else
                log "WARNING Skipping NuisanceReg. Please set flags_EPI_NuisanceReg=true to run Nuisance Regression"
            fi

            if ${flags_EPI_PhysiolReg}; then

                cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_PhysiolReg.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at fMRI_A_EPI_PhysiolReg. exiting."
                    exit 1
                fi  

            else
                log "WARNING Skipping Physiological Regressors. Please set flags_EPI_PhysiolReg=true to run Phys Regression"
            fi   

            ### AAK - COMMENT OUT THIS SECTION WHEN TESTING TO AVOID HAVING TO RUN NUISANCE REG
            if ${flags_EPI_PhysiolReg} || ${flags_EPI_NuisanceReg}; then

                echo "APPLYING REGRESSORS"

                cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_ApplyReg.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at fMRI_A_EPI_ApplyReg. exiting."
                    exit 1
                fi  
            fi             


            # if ${flags_EPI_DemeanDetrend}; then

            #     cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_DemeanDetrend.sh"
            #     echo $cmd
            #     eval $cmd
            #     exitcode=$?

            #     if [[ ${exitcode} -ne 0 ]] ; then
            #         echoerr "problem at fMRI_A_EPI_DemeanDetrend. exiting."
            #         exit 1
            #     fi  
            # fi             

            # if ${flags_EPI_MotionRegressors}; then

            #     cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_MotionRegressors.sh"
            #     echo $cmd
            #     eval $cmd
            #     exitcode=$?

            #     if [[ ${exitcode} -ne 0 ]] ; then
            #         echoerr "problem at fMRI_A_EPI_MotionRegressors. exiting."
            #         exit 1
            #     fi  
            # fi             



            # if ${flags_EPI_MelodicUnwarped}; then 

            #     echo "0. Merge Melodic Unwarpped Images"

            #     path_EPIMelodicUnwarped=${EPIpath}/${configs_melodicUnwarpedFolder}

            #     if [[ -d ${path_EPIMelodicUnwarped} ]]; then
            #         cmd="fslmerge -tr ${EPIpath}/0_epi_unwarped ${path_EPIMelodicUnwarped}/uf*.nii.gz ${TR}"
            #     else
            #         log "ERROR MELODIC UNWARPED folder does not exist"
            #     fi
            # fi 


        fi
    fi 
done



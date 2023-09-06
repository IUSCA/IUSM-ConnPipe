
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
done < <(find ${path2data}/${SUBJ} -maxdepth 1 -type d -iname "${configs_epiFolder}*" -print0 | sort -z)

#epiList[0]=`find $path2data/${SUBJ}/ -maxdepth 1 -type d -name "EPI*"`

if [ ${#epiList[@]} -eq 0 ]; then 
    echo "No EPI directories found for subject $SUBJ. Check consistency of naming convention."
    exit 1
else
    echo "There are ${#epiList[@]} EPI-series "
fi

export first_FMcalc=false

for ((i=0; i<${#epiList[@]}; i++)); do

    ind=`echo ${epiList[$i]} | sed 's/.*\EPI//'`
    re='^[0-9]+$'

    if [[ ! -d "${epiList[$i]}" ]]; then
        echo "${epiList[$i]} directory not found"
        exit 1

    elif ! [[ $ind =~ $re ]] ; then  # if EPI dir has no session number
        echo "EPI directory ${epiList[$i]} has no session number"
        echo "Running f_MRI_A on ${epiList[$i]}"
    
    elif [[ $ind =~ $re ]] ; then

        echo "==== ind = ${ind}"

        if [ $ind -lt "${configs_EPI_epiMin}" ] || [ $ind -gt "${configs_EPI_epiMax}" ]; then
            log "WARNING Skipping f_MRI_A processing on ${epiList[$i]}. Scan session is not within the epiMin and epiMax configuration settings."
            continue
        fi
    fi

    ################################################################
    # specify paths to raw EPI data (RD) and EPI derivatives

    echo "Setting EPInum variable to ${ind}"
    export EPInum=${ind}

    export RD_EPIpath="${epiList[$i]}"
    epi_dir="$(basename -- ${RD_EPIpath})"
    export EPIpath="${path2derivs}/${SUBJ}/${epi_dir}"
    if [[ ! -d "${EPIpath}" ]]; then
        mkdir -p ${EPIpath}
    fi    
    
    log "Runnin fMRI_A on subject ${SUBJ}"
    log "Working on EPI-series ${RD_EPIpath}"
    log "Writing output to ${EPIpath}"
    log "EPI session number ${EPInum}"
    

    # ### Convert dcm2nii
    if ${flags_EPI_dcm2niix}; then

        echo "=================================="
        echo "0. Dicom to NIFTI conversion"
        echo "=================================="

        path_EPIdcm=${RD_EPIpath}/${configs_dcmFolder}
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

    else
        log "SOURCING header parameters from file ${EPIpath}/0_param_dcm_hdr.sh"

        if [[ -f "${EPIpath}/0_param_dcm_hdr.sh" ]]; then
            source ${EPIpath}/0_param_dcm_hdr.sh 
        else
            log "File ${EPIpath}/0_param_dcm_hdr.sh not found; Please set flags_EPI_ReadHeaders=true. Exiting..."
            exit 1
        fi     

    fi


    if ${flags_EPI_SpinEchoUnwarp}; then 
    
        cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_SpinEchoUnwarp.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at fMRI_A_EPI_SpinEchoUnwarp. exiting."
            exit 1
        else
            log "First calculation of FM done"
            first_FMcalc=true
        fi
        
    fi 

    if ${flags_EPI_GREFMUnwarp}; then 
        
        cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_GREFMUnwarp.sh"
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

        # 0_param_dcm_hdr.sh has been modified in MotionCorr, so needs to be sourced again
        log "Sourcing parameters read from header and written to ${EPIpath}/0_param_dcm_hdr.sh"
        source ${EPIpath}/0_param_dcm_hdr.sh
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

        if [[ ${flags_NuisanceReg} == "AROMA" ]] || [[ ${flags_NuisanceReg} == "AROMA_HMP" ]]; then

            if ${AROMA_exists}; then

                log "WARNING -- Skipping AROMA. User has indicated that AROMA output already exists"

            else

                cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_AROMA.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at fMRI_A_EPI_AROMA. exiting."
                    exit 1
                fi                
            fi
        fi
            
        if [[ ${flags_NuisanceReg} == "HMPreg" ]] || [[ ${flags_NuisanceReg} == "AROMA_HMP" ]]; then

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



    if ${flags_EPI_regressOthers}; then  
        ### Always run regressOthers - it computes Global signal for QC purposes, but won't be applied to regression
        echo "Other Regressors"

        cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_regressOthers.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at fMRI_A_EPI_regressOthers. exiting."
            exit 1
        fi  
    fi  



    if ${flags_EPI_ApplyReg}; then  

        echo "APPLYING REGRESSORS"

        cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_ApplyReg.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        echo "$(free -h)"

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at fMRI_A_EPI_ApplyReg. exiting."
            exit 1
        fi  

    fi  

    # now we can create a post-reg nR that gets built as we add post-regression analyses. 
    export post_nR="${nR}"

    # now we can update nR
    if ${flags_EPI_DVARS}; then
        export post_nR="${post_nR}_DVARS"
    fi


    if ${flags_EPI_postReg}; then  

        echo "Post Regression Nuisance Removal"


        if ${flags_EPI_DemeanDetrend}; then

            cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_DemeanDetrend.sh"
            echo $cmd
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] ; then
                echoerr "problem at fMRI_A_EPI_DemeanDetrend. exiting."
                exit 1
            fi  

            export post_nR="${post_nR}_dmdt"
        fi             

        if ${flags_EPI_BandPass}; then

            cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_BandPass.sh"
            echo $cmd
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] ; then
                echoerr "problem at fMRI_A_EPI_BandPass. exiting."
                exit 1
            fi  

            export post_nR="${post_nR}_butter"
        fi 

        if ${configs_EPI_scrub}; then

            cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_Scrub.sh"
            echo $cmd
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] ; then
                echoerr "problem at fMRI_A_EPI_Scrub. exiting."
                exit 1
            fi  

            export post_nR="${post_nR}_scrubbed"

        fi              
    fi      


    if ${flags_EPI_ROIs}; then

        cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_ROIs.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at fMRI_A_EPI_ROIs. exiting."
            exit 1
        fi  
    fi 


    if ${flags_EPI_ReHo}; then

        cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_ReHo.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at fMRI_A_EPI_ReHo. exiting."
            exit 1
        fi  
    fi 

    if ${flags_EPI_ALFF}; then

        cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_ALFF.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at fMRI_A_EPI_ALFF. exiting."
            exit 1
        fi  
    fi 

    export post_nR=""

done



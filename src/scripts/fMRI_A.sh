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
# Load IU Quartz supercomuter modules
module load fsl/6.0.5.2
module load python/3.11.4 

# FSL
# set FSL env vars for fsl_sub.IU or fsl_sub.orig
if [[ -z ${FSLDIR} ]] ; then
	echoerr "FSLDIR not set"
	exit 1
fi
############################################################################### 

log --no-datetime "fMRI_A"

# If multi-run is set:
if [ -n "$configs_EPI_runMin" ]; then
    echo "Non-empty configs_EPI_runMin. Checking for _run- tag..."
    # Generate list of EPI scan directories
    declare -a epiList
    while IFS= read -r -d $'\0' REPLY; do 
        epiList+=( "$REPLY" )
    done < <(find ${EPIpath_raw} -maxdepth 1 -type f -iname "*_task-${configs_EPI_task}*_run-*nii.gz" -print0 | sort -z)
    
    if [ ${#epiList[@]} -eq 0 ]; then 
        echo "No raw func files with _run- tag found for subject $SUBJ. Check consistency of naming convention."
        exit 1
    elif [ ${#epiList[@]} -gt 1 ]; then
        echo "Multiple raw func runs found for subject $SUBJ."
        echo "There are ${#epiList[@]} EPI-series "
    else
        echo "Single raw func with _run tag found for subject $SUBJ."
        echo "There are ${#epiList[@]} EPI-series "
    fi
    rtag=1
else # else no run tag assumed
    declare -a epiList
    while IFS= read -r -d $'\0' REPLY; do 
        epiList+=( "$REPLY" )
    done < <(find ${EPIpath_raw} -maxdepth 1 -type f -iname "*_task-${configs_EPI_task}*nii.gz" -print0 | sort -z)

    if [ ${#epiList[@]} -eq 0 ]; then 
        echo "No raw func files found for subject $SUBJ. Check consistency of naming convention."
        exit 1
    elif [ ${#epiList[@]} -gt 1 ]; then
        echo "Multiple raw func files found for subject $SUBJ. Check for proper naming convention. OR"
        echo "Include configs_EPI_runMin and Max if _run- tag is used."
        exit 1
    else
        echo "There are ${#epiList[@]} EPI-series "
    fi
    rtag=0
fi

#LOOPING OVER EPI SESSIONS
for ((i=0; i<${#epiList[@]}; i++)); do
######################################################################################
    # Operating on the scans set in configs.
    log "fMRI_A on subject ${SUBJ}"
    log --no-datetime "task - ${configs_EPI_task}"

    if [ ${rtag} -eq 1 ]; then
        ind=$(echo ${epiList[$i]} | sed 's/.*run-\(.*\)_.*/\1/')
        re='^[0-9]+$'
        
        if ! [[ $ind =~ $re ]] ; then  # if EPI has no run tag
            echo "Raw func: ${epiList[$i]} has no numeric run tag."
            echo "Running f_MRI_A on ${epiList[$i]}"
            log --no-datetime "run - ${ind}"
            export EPIfile="${epiList[$i]}"
            export EPIrun_out="${EPIpath}/task-${configs_EPI_task}_run-${ind}"
        elif [[ $ind =~ $re ]] ; then
            if [ $ind -lt ${configs_EPI_runMin} ] || [ $ind -gt ${configs_EPI_runMax} ]; then
                log "WARNING Skipping f_MRI_A processing on ${epiList[$i]}. Scan run is not within the epiMin and epiMax configuration settings."
                break
            else
                log --no-datetime "run - ${ind}"
                export EPIfile="${epiList[$i]}"
                export EPIrun_out="${EPIpath}/task-${configs_EPI_task}_run-${ind}"
            fi
        fi
    else
        export EPIfile="${epiList[$i]}"
        export EPIrun_out="${EPIpath}/task-${configs_EPI_task}"
    fi

    log --no-datetime "func derivative directory:"
    log --no-datetime "${EPIrun_out}"
    if [[ ! -d "${EPIrun_out}" ]]; then
        mkdir -p ${EPIrun_out}
    fi

######################################################################################
    #### Read scan info from json
    if ${flags_EPI_ReadJson}; then

        cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_ReadJson.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "Problem at fMRI_A_EPI_ReadJson. exiting."
            exit 1
        fi  

        # Source the scan info saved by ReadJson.
        log "Sourcing parameters read from json and written to ${EPIrun_out}/0_param_dcm_hdr.sh"
        if [[ -f "${EPIrun_out}/0_param_dcm_hdr.sh" ]]; then
            source ${EPIrun_out}/0_param_dcm_hdr.sh   
        else
            log --no-datetime "File ${EPIrun_out}/0_param_dcm_hdr.sh not found. Check that ReadJson succeeded in creating parameter file."
            exit 1
        fi

    else
        log "ReadJson skipped. Checking for existing parameter file."

	    if [[ -f "${EPIrun_out}/0_param_dcm_hdr.sh" ]]; then
            log --no-datetime "Sourcing scan parameters from existing file: ${EPIrun_out}/0_param_dcm_hdr.sh"
            source ${EPIrun_out}/0_param_dcm_hdr.sh 
	    else
            log "File ${EPIrun_out}/0_param_dcm_hdr.sh not found: Please set flags_EPI_ReadJson=true. Exiting..."
            exit 1
	    fi
    fi

######################################################################################
    #### Distortion Correction (Spin Echo or Gradient Echo Unwarping) 
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
# SKIPPING THIS FOR NOW FOR NOW WILL NEED TO RECODE LATER FOR BIDS
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

######################################################################################
    #### Slice Timing Correction (for longer TR acquisitions) 
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

######################################################################################
    #### Motion Correction (mcflirt)
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
        log "Sourcing parameters read from header and written to ${EPIrun_out}/0_param_dcm_hdr.sh"
        source ${EPIrun_out}/0_param_dcm_hdr.sh
    fi 

######################################################################################
    #### Registration of T1 to epi space.
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
    
######################################################################################
    #### Registration of parcellations to epi space.
    if ${flags_EPI_RegOthers}; then
        
        cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_RegOthers.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at fMRI_A_EPI_RegOthers. exiting."
            exit 1
        fi  
    fi 

######################################################################################
    #### Normalization to a global 4D mean of 1000
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

######################################################################################
    if ${flags_EPI_NuisanceReg}; then
        msg2file "# =========================================================="
        msg2file "# 5  Nuisance Regression. "
        msg2file "# =========================================================="

        if [[ ${flags_NuisanceReg} == "AROMA" ]] || [[ ${flags_NuisanceReg} == "AROMA_HMP" ]]; then

            if ${AROMA_exists}; then

                log "WARNING -- Skipping AROMA. User has indicated that AROMA output already exists."

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

######################################################################################
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

######################################################################################
    if ${flags_EPI_GS}; then  

        cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_regressGS.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at fMRI_A_EPI_regressGS. Exiting."
            exit 1
        fi  
    fi

######################################################################################
    if ${flags_EPI_FreqFilt}; then  


        if [[ ${flags_FreqFilt} == "DCT" ]]; then

            cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_regressDCT.sh"
            echo $cmd
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] ; then
                echoerr "problem at fMRI_A_EPI_regressDCT. exiting."
                exit 1
            fi                
            
        elif [[ ${flags_FreqFilt} == "BPF" ]]; then

            log "Bandpass filter will be applied to residuals in ApplyReg."

        fi 

    else
        log "WARNING Skipping Frequency Filters. Please set flags_EPI_FreqFilt=true to run frequency filtering"
    fi
    
######################################################################################
    if ${flags_EPI_ApplyReg}; then  

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

######################################################################################
     
    if ${flags_EPI_scrub}; then

        cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_Scrub.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at fMRI_A_EPI_Scrub. exiting."
            exit 1
        fi  
    fi 

######################################################################################
    if ${flags_EPI_ROIs}; then

        
        if ${configs_EPI_despike}; then
            export post_nR="${nR}_despiked"
        elif ${flags_EPI_scrub}; then
            export post_nR="${nR}_scrubbed"
        else
            export post_nR="${nR}"
        fi

        cmd="${EXEDIR}/src/scripts/fMRI_A_EPI_ROIs.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at fMRI_A_EPI_ROIs. exiting."
            exit 1
        fi  
    fi 



######################################################################################
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

module unload fsl
module unload python
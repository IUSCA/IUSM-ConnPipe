#!/bin/bash

#module load python/3.11.4
module load fsl/6.0.5.2
module load ants/2.3.5

# Checking input arguments:
if (($# != 2)); then
	echo "Incorrect number of input arguments:"	
	echo "Need input path/name to config.sh and subj2run.txt"
	echo "Usage: `basename $0` </path/to/config.sh> </path/to/subj2run.txt>"
	exit 1
fi
config=$1
subj2run=$2

# Location of package and scripts [if hpc_main is in pipeline directory]:
 export EXEDIR=$(dirname "$(readlink -f "$0")")

# This change allows me to run the pipeline from any directory.
# export EXEDIR="/N/project/kbase-imaging/connpipe_job_test/IUSM-ConnPipe"

source ${EXEDIR}/src/func/bash_funcs.sh
source $config

# Exporting path/file dependencies.
#============================================================================
export pathMNItmplates="${pathSM}/MNI_templates"
export pathBrainmaskTemplates="${pathSM}/brainmask_templates"
export pathParcellations="${pathSM}/Parcellations"
export PYpck="${pathSM}/python-pkgs"

# Creating a derivative directory for connpipe. 
#============================================================================

# if [[ ! -d "${path2derivs}" ]]; then
# 	mkdir ${path2derivs}
# fi

path2derivs="$path2derivs/connpipe"
if [[ ! -d "${path2derivs}" ]]; then
	mkdir ${path2derivs}
fi

# Setting [anat] denoising option.
#============================================================================
if [[ "${configs_T1_denoised}" == "ANTS" ]]; then 
	export configs_fslanat="T1_denoised_ANTS"
elif [[ "${configs_T1_denoised}" == "SUSAN" ]]; then
	export configs_fslanat="T1_denoised_SUSAN"
elif [[ "${configs_T1_denoised}" == "NONE" ]]; then  # do not perform denoising 
	export configs_fslanat="anat"
fi

# Defining scanner specific header tags for [func] f_MRI_A.
#============================================================================
if ${fMRI_A}; then
    if [[ ${scanner} == "SIEMENS" ]]; then
        export scanner_param_TR="RepetitionTime"  # "RepetitionTime" for Siemens; "tr" for GE
        export scanner_param_TE="EchoTime"  # "EchoTime" for Siemens; "te" for GE
        export scanner_param_FlipAngle="FlipAngle"  # "FlipAngle" for Siemens; "flip_angle" for GE
        export scanner_param_EffectiveEchoSpacing="EffectiveEchoSpacing"  # "EffectiveEchoSpacing" for Siemens; "effective_echo_spacing" for GE
        export scanner_param_BandwidthPerPixelPhaseEncode="BandwidthPerPixelPhaseEncode"  # "BandwidthPerPixelPhaseEncode" for Siemens; unknown for GE
        export scanner_param_slice_fractimes="SliceTiming"  # "SliceTiming" for Siemens; "slice_timing" for GE
        export scanner_param_TotalReadoutTime="TotalReadoutTime"
        export scammer_param_AcquisitionMatrix="AcquisitionMatrixPE"
        export scanner_param_PhaseEncodingDirection="PhaseEncodingDirection"
    elif [[ ${scanner} == "GE" ]]; then
        export scanner_param_TR="tr"  # "RepetitionTime" for Siemens; "tr" for GE
        export scanner_param_TE="te"  # "EchoTime" for Siemens; "te" for GE
        export scanner_param_FlipAngle="flip_angle"  # "FlipAngle" for Siemens; "flip_angle" for GE
        export scanner_param_EffectiveEchoSpacing="effective_echo_spacing"  # "EffectiveEchoSpacing" for Siemens; "effective_echo_spacing" for GE
        export scanner_param_BandwidthPerPixelPhaseEncode="pixel_bandwidth"  # "BandwidthPerPixelPhaseEncode" for Siemens; unknown for GE
        export scanner_param_slice_fractimes="slice_timing"  # "SliceTiming" for Siemens; "slice_timing" for GE
        export scanner_param_TotalReadoutTime="TotalReadoutTime"
        export scammer_param_AcquisitionMatrix="acquisition_matrix"
        export scanner_param_PhaseEncodingDirection="phase_encode_direction"
    fi

 # Checking that ony one UNWARP option is selected.
 #============================================================================
    if ${flags_EPI_SpinEchoUnwarp} && ${flags_EPI_GREFMUnwarp}; then
        log "ERROR --	Please select one option only: Spin Echo Unwarp or Gradient Echo Unwarp. Exiting... "
        exit 1
    fi

 # Setting nuisance regression dependencies.
 #============================================================================
    if [[ ${flags_NuisanceReg} == "AROMA" ]]; then # if using ICA-AROMA

        nR="aroma" # set filename postfix for output image
        
        # Use the ICA-AROMA package contained in the ConnPipe-SuppMaterials
        ICA_AROMA_path="${PYpck}/ICA-AROMA" 
       # ICA_AROMA_path="/N/project/KarekenLab/ConnPipelineSM/python-pkgs/ICA-AROMA"
        export run_ICA_AROMA="python ${ICA_AROMA_path}/ICA_AROMA.py"
        ## UNCOMMENT FOLLOWING LINE **ONLY** IF USING HPC ica-aroma MODULE:
        # export run_ICA_AROMA="ICA_AROMA.py"

        export configs_EPI_resting_file='/AROMA/AROMA-output/denoised_func_data_nonaggr.nii.gz'

        export configs_EPI_numReg=0   # make sure numReg variable is set to 0

    elif [[ ${flags_NuisanceReg} == "HMPreg" ]]; then   # if using Head Motion Parameters
                        
        nR="hmp${configs_EPI_numReg}"   # set filename postfix for output image
        
        if [[ "${configs_EPI_numReg}" -ne 12 && "${configs_EPI_numReg}" -ne 24 ]]; then
            log "ERROR The variable config_EPI_numReg must have values '12' or '24'. \
                Please set the corect value in the config.sh file"
                exit 1
        fi	

        export configs_EPI_resting_file='/4_epi.nii.gz'    

    elif [[ ${flags_NuisanceReg} == "AROMA_HMP" ]]; then   # if using AROMA + Head Motion Parameters

        nR="aroma_hmp${configs_EPI_numReg}" # set filename postfix for output image
        
        # Use the ICA-AROMA package contained in the ConnPipe-SuppMaterials
        ICA_AROMA_path="${PYpck}/ICA-AROMA" 
        export run_ICA_AROMA="python ${ICA_AROMA_path}/ICA_AROMA.py"
        ## UNCOMMENT FOLLOWING LINE **ONLY** IF USING HPC ica-aroma MODULE:
        # export run_ICA_AROMA="ICA_AROMA.py"

        export configs_EPI_resting_file='/AROMA/AROMA-output/denoised_func_data_nonaggr.nii.gz'
        
        if [[ "${configs_EPI_numReg}" -ne 12 && "${configs_EPI_numReg}" -ne 24 ]]; then
            log "ERROR The variable config_EPI_numReg must have values '12' or '24'. \
                Please set the corect value in the config.sh file"
                exit 1
        fi	

    else
        log "ERROR - flag_NuisanceReg must be either AROMA or HMPreg or AROMA_HMP"
        exit 1
    fi

 # Setting physiological regression dependencies.
 #============================================================================
    if [[ ${flags_PhysiolReg} == "aCompCor" ]]; then  ### if using aCompCorr

        if [[ "${configs_EPI_numPhys}" -ge 0 && "${configs_EPI_numPhys}" -le 5 ]]; then
            nR="${nR}_pca${configs_EPI_numPhys}"
        elif [[ "${configs_EPI_numPhys}" -ge 5 ]]; then
            nR="${nR}_pca"
        fi

    elif [[ ${flags_PhysiolReg} == "meanPhysReg" ]]; then

        nR="${nR}_mPhys${configs_EPI_numPhys}"

        if [[ "${configs_EPI_numPhys}" -ne 2 \
            && "${configs_EPI_numPhys}" -ne 4 \
            && "${configs_EPI_numPhys}" -ne 8 ]]; then
                log "ERROR the variable configs_EPI_numPhys must have values '2', '4' or '8'. \
                    Please set the corect value in the config.sh file"
                exit 1
        fi	
    fi

    export regPath=${flags_NuisanceReg}/${flags_PhysiolReg}

 # Global Signal
#============================================================================
    if ${flags_EPI_GS}; then
        nR="${nR}_Gs${configs_EPI_numGS}"
    else 
        export configs_EPI_numGS=0
    fi 

# Frequency Filtering
#============================================================================
    if [[ ${flags_FreqFilt} == "DCT" ]]; then  ### if using discrete cosine transform
        nR="${nR}_DCT"
    elif [[ ${flags_FreqFilt} == "BPF" ]]; then
        nR="${nR}_BPF"
        export configs_EPI_dctfMin=0
        
    fi

# DVARS-based time point scrubbing (Pham, ..., Mejia. NeuroImage 2023 and Afyouni $ Nichols, 2018)
#============================================================================
    if ${configs_EPI_despike}; then
        # nR=nR_DVARS -- this gets updated in fMRI_A
        # after regression is applied. This allows us to save both
        # sets of residuals with and without DVARS.
        export configs_EPI_path2DVARS="${EXEDIR}/src/func/"
    fi

    export nR 
fi

#################################################################################
#################################################################################

## main
main() {

echo "START running Connectivity Pipeline on the following subjects:"
# Define arrays
declare -a SUBJECTS=()
declare -a SESSIONS=()

# Read the file line by line
while IFS=" " read -r col1 col2; do
    # Add elements to arrays
    SUBJECTS+=("$col1")
    SESSIONS+=("$col2")
done < "${subj2run}"


# IFS=$'\r\n' GLOBIGNORE='*' command eval 'SUBJECTS=($(cat ${subj2run}))'
log --no-datetime "subjects: ${SUBJECTS[@]}"
log --no-datetime "sessions: ${SESSIONS[@]}"


echo "##################"

# #### START PROCESSING SUBJECTS ###############
# Determine the length of the arrays
nsubj=${#SUBJECTS[@]}

# Loop through both arrays with a counter
for ((i = 0; i < nsubj; i++)); do
    log "Processing ${SUBJECTS[i]}_${SESSIONS[i]}"

    start=`date +%s`

    export SUBJ=${SUBJECTS[i]}  #${SUBJdir}
    log "Subject ${SUBJ}"
    export SESS=${SESSIONS[i]}  #${SUBJdir}
    log "Session ${SESS}"

    # create sub-ses directory so that log files can be written
    export path2ses="${path2derivs}/${SUBJ}/${SESS}"
    if [[ ! -d "${path2ses}" ]]; then
        mkdir -p ${path2ses}
    fi

    # specify name of logfile written inside each subjects dir
    today=$(date +"%m_%d_%Y_%H_%M")
    export logfile_name="${path2ses}/out_${today}"
    export QCfile_name="${path2ses}/qc"
    export ERRfile_name="${path2derivs}/error_report"


    log "############################ T1_PREPARE_A #####################################"

    export T1path="${path2ses}/anat"

    if $T1_PREPARE_A; then
        ## Path to raw data
        export T1path_raw="${path2data}/${SUBJ}/${SESS}/anat"

        if [ -d "$T1path_raw" ]; then
        ## Path to derivatives
            if [[ ! -d "${T1path}" ]]; then
                mkdir -p ${T1path}
            fi

            echo "============== T1path is ${T1path} =============="

            cmd="${EXEDIR}/src/scripts/t1_prepare_A.sh"
            echo $cmd
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] ; then
                echoerr "${SUBJ}_${SESS}: problem at T1_PREPARE_A. exiting."
                dateTime=`date`
                echo "### $dateTime -" >> ${ERRfile_name}.log
                echo "${SUBJ}_${SESS} ERROR -- problem at T1_PREPARE_A.  - " >> ${ERRfile_name}.log
                echo "###" >> ${ERRfile_name}.log 
                continue
            fi
        else
            echoerr "${SUBJ}_${SESS}: Raw T1 directory doesn't exist: $T1path_raw"
            echoerr "Skipping further analysis"
            dateTime=`date`
            echo "### $dateTime -" >> ${ERRfile_name}.log
            echo -e "${SUBJ}_${SESS}: Raw T1 directory doesn't exist: $T1path_raw \n skipping further analysis" >> ${ERRfile_name}.log
            echo "###" >> ${ERRfile_name}.log 
            continue
        fi
    else 
        log "SKIP T1_PREPARE_A for subject ${SUBJ}_${SESS}"
    fi 


    ######################################################################################
    log "############################# T1_PREPARE_B #####################################"

    if $T1_PREPARE_B; then

        if [[ -d "$T1path" ]]; then 

            cmd="${EXEDIR}/src/scripts/t1_prepare_B.sh"
            echo $cmd
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] ; then
                echoerr "${SUBJ}_${SESS}: problem at T1_PREPARE_B. exiting."
                dateTime=`date`
                echo "### $dateTime -" >> ${ERRfile_name}.log
                echo "${SUBJ}_${SESS}: ERROR -- problem at T1_PREPARE_B.  - " >> ${ERRfile_name}.log
                echo "###" >> ${ERRfile_name}.log                   
                continue
            fi
                    
        else
            echoerr "${SUBJ}_${SESS}: derivative T1 directory doesn't exist: $T1path"
            echoerr "Skipping further analysis"
            dateTime=`date`
            echo "### $dateTime -" >> ${ERRfile_name}.log
            echo -e "${SUBJ}_${SESS}: Derivative T1 directory doesn't exist: $T1path \n skipping further analysis" >> ${ERRfile_name}.log
            echo "###" >> ${ERRfile_name}.log 
            continue
        fi
    else
        log "SKIP T1_PREPARE_B for subject ${SUBJ}_${SESS}"
    fi 

    ######################################################################################
    log "############################# fMRI_A ###########################################"

        if $fMRI_A; then

            if [[ -d "$T1path" ]]; then 
                ## Path to raw data
                export EPIpath_raw="${path2data}/${SUBJ}/${SESS}/func"
                export FMAPpath_raw="${path2data}/${SUBJ}/${SESS}/fmap"

                if [ -d "$EPIpath_raw" ]; then
    	        ## Path to derivatives
    	            export EPIpath="${path2ses}/func"
    	            if [[ ! -d "${EPIpath}" ]]; then
        	            mkdir -p ${EPIpath}
    	            fi
                fi 

                log --no-datetime "USER SET SCANNER MANUFACTURER: ${scanner}"

                cmd="${EXEDIR}/src/scripts/fMRI_A.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "${SUBJ}_${SESS}: problem at fMRI_A. exiting."
                    dateTime=`date`
                    echo "### $dateTime -" >> ${ERRfile_name}.log
                    echo "${SUBJ}_${SESS} ERROR -- problem at fMRI_A.  - " >> ${ERRfile_name}.log
                    echo "###" >> ${ERRfile_name}.log                    
                    continue
                fi
                        
            else
                echoerr "${SUBJ}_${SESS}: derivative T1 directory doesn't exist: $T1path"
                echoerr "Skipping further analysis"
                dateTime=`date`
                echo "### $dateTime -" >> ${ERRfile_name}.log
                echo -e "${SUBJ}_${SESS}: Derivative T1 directory doesn't exist: $T1path \n skipping further analysis" >> ${ERRfile_name}.log
                echo "###" >> ${ERRfile_name}.log 
                continue
            fi
        else
            log "SKIP fMRI_A for subject ${SUBJ}_${SESS}"
        fi 

    ######################################################################################
    log "############################# DWI_A ############################################"

        if $DWI_A; then

            export DWIpath_raw="${path2data}/${SUBJ}/${SESS}/dwi"

            ## Path to derivatives
            export DWIpath="${path2ses}/dwi"
            if [[ ! -d "${DWIpath}" ]]; then
                mkdir -p ${DWIpath}
            fi

            if [[ -d "${DWIpath}" ]]; then 

                cmd="${EXEDIR}/src/scripts/DWI_A.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "${SUBJ}_${SESS}: problem at DWI_A. exiting."
                    dateTime=`date`
                    echo "### $dateTime -" >> ${ERRfile_name}.log
                    echo "${SUBJ}_${SESS} ERROR -- problem at DWI_A.  - " >> ${ERRfile_name}.log
                    echo "###" >> ${ERRfile_name}.log
                    continue
                fi
                        
            else
                echoerr "${SUBJ}_${SESS}: DWI directory doesn't exist: $DWIpath"
                echoerr "Skipping further analysis"
                dateTime=`date`
                echo "### $dateTime -" >> ${ERRfile_name}.log
                echo -e "${SUBJ}_${SESS}: DWI directory doesn't exist: $DWIpath \n skipping further analysis" >> ${ERRfile_name}.log
                echo "###" >> ${ERRfile_name}.log 
                continue
            fi
        else
            log "SKIP DWI_A for subject ${SUBJ}_${SESS}"
        fi 

    ######################################################################################
    log "# ############################ DWI_B ############################################"

        if $DWI_B; then

            if [[ -d "$T1path" ]]; then 
        
                export DWIpath="${path2ses}/dwi"

                if [[ -d "${DWIpath}" ]]; then 

                    cmd="${EXEDIR}/src/scripts/DWI_B.sh"
                    echo $cmd
                    eval $cmd
                    exitcode=$?

                    if [[ ${exitcode} -ne 0 ]] ; then
                        echoerr "${SUBJ}_${SESS}: problem at DWI_B. exiting."
                        dateTime=`date`
                        echo "### $dateTime -" >> ${ERRfile_name}.log
                        echo "${SUBJ}_${SESS} ERROR -- problem at DWI_B.  - " >> ${ERRfile_name}.log
                        echo "###" >> ${ERRfile_name}.log
                        continue
                    fi
                        
                else
                    echoerr "${SUBJ}_${SESS}: DWI directory doesn't exist: $DWIpath"
                    echoerr "Skipping further analysis"
                    dateTime=`date`
                    echo "### $dateTime -" >> ${ERRfile_name}.log
                    echo -e "${SUBJ}_${SESS}: DWI directory doesn't exist: $DWIpath \n skipping further analysis" >> ${ERRfile_name}.log
                    echo "###" >> ${ERRfile_name}.log 
                    continue
                fi
            else
                echoerr "${SUBJ}_${SESS}: derivative T1 directory doesn't exist: $T1path"
                echoerr "Skipping further analysis"
                dateTime=`date`
                echo "### $dateTime -" >> ${ERRfile_name}.log
                echo -e "${SUBJ}_${SESS}: Derivative T1 directory doesn't exist: $T1path \n skipping further analysis" >> ${ERRfile_name}.log
                echo "###" >> ${ERRfile_name}.log 
                continue
            fi
        else
            log "SKIP DWI_B for subject ${SUBJ}_${SESS}"
        fi 

    # ################################################################################
    # ################################################################################

        ## time it
        end=`date +%s`
        runtime=$((end-start))
        log "SUBJECT ${SUBJ}_${SESS} runtime: $runtime"

    echo "#################################################################################"
    echo "#################################################################################"
    
    dateTime=`date`
    echo "### $dateTime -" >> ${ERRfile_name}.log
    echo "${SUBJ}_${SESS} COMPLETED -- runtime $runtime sec - " >> ${ERRfile_name}.log
    echo "###" >> ${ERRfile_name}.log

done    

} # main

# ################################################################################
# ################################################################################
# ## run it

main "$@" 2>&1 | tee -a test_log_main.log 


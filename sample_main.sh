#!/bin/bash

# # IU modules load
module unload python 
module load python/3.9.8 
module load fsl/6.0.1
module load mricrogl
module load gsl
module load afni
module load ants
#module load ica-aroma/0.4.4
module load mrtrix/3.0
# module load singularity

# FSL
# set FSL env vars for fsl_sub.IU or fsl_sub.orig
if [[ -z ${FSLDIR} ]] ; then
	echoerr "FSLDIR not set"
	exit 1
fi

# where this package of scripts are
export EXEDIR=$(dirname "$(readlink -f "$0")")

source ${EXEDIR}/src/func/bash_funcs.sh

################################################################################
# USER INSTRUCTIONS- PLEASE SET THE NAME OF THE CONFIG FILE TO READ
source ${EXEDIR}/config.sh
################################################################################


################################################################################
############################ Dependencies ######################################

export pathMNItmplates="${pathSM}/MNI_templates"

export pathFSLstandard="${FSLDIR}/data/standard"

if [[ -e "${pathFSLstandard}/MNI152_T1_2mm_brain.nii.gz" ]]; then
    fileMNI2mm="${pathFSLstandard}/MNI152_T1_2mm_brain.nii.gz"
else
    fileMNI2mm="${pathMNItmplates}/MNI152_T1_2mm_brain.nii.gz"
fi

if ${configs_T1_useMNIbrain}; then
    export path2MNIref="${pathFSLstandard}/MNI152_T1_1mm_brain.nii.gz"
else
    export path2MNIref="${pathFSLstandard}/MNI152_T1_1mm.nii.gz"
fi

export pathBrainmaskTemplates="${pathSM}/brainmask_templates"
export pathParcellations="${pathSM}/Parcellations"
export PYpck="${pathSM}/python-pkgs"


# # Setting denoising option
# #===========================================================================================					
if [[ "${configs_T1_denoised}" == "ANTS" ]]; then 
	export configs_fslanat="T1_denoised_ANTS"
	echo "USING ANTS FOR DENOISING"
elif [[ "${configs_T1_denoised}" == "SUSAN" ]]; then
	export configs_fslanat="T1_denoised_SUSAN"
	echo "USING SUSAN FOR DENOISING"
elif [[ "${configs_T1_denoised}" == "NONE" ]]; then  # do not perform denoising 
	export configs_fslanat=${configs_T1}
	echo "T1 WILL NOT BE DENOISED"
fi

# define header tags for f_MRI_A
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

    # check that ony one UNWARP option is selected 
    if ${flags_EPI_SpinEchoUnwarp} && ${flags_EPI_GREFMUnwarp}; then
        log "ERROR --	Please select one option only: Spin Echo Unwarp or Gradient Echo Unwarp. Exiting... "
        exit 1
    fi

    # Nuisance Regression
    # #===========================================================================================

    if [[ ${flags_NuisanceReg} == "AROMA" ]]; then # if using ICA-AROMA

        nR="aroma" # set filename postfix for output image
        
        # Use the ICA-AROMA package contained in the ConnPipe-SuppMaterials
        ICA_AROMA_path="${PYpck}/ICA-AROMA" 
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


    # Pyhsiological Regression
    # #===========================================================================================

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

    # Other regressors and file name settings
    # #===========================================================================================

    if ${flags_EPI_GS}; then
        nR="${nR}_Gs${configs_EPI_numGS}"
    else 
        export configs_EPI_numGS=0
    fi 

                            
    if ${configs_EPI_DCThighpass}; then
        nR="${nR}_DCT"
    else 
        export configs_EPI_dctfMin=0
    fi

    if ${flags_EPI_DVARS}; then
        # nR=nR_DVARS -- this gets updated in fMRI_A
        # after regression is applied. This allows us to save both
        # sets of residuals with and without DVARS.
        export configs_EPI_path2DVARS="${EXEDIR}/src/func/"
    fi

    if ${configs_EPI_DCThighpass} && ${flags_EPI_BandPass}; then
        log "ERROR 	Please select one option only: DCT high-pass or Butterworth filtering. Exiting... "
        exit 1
    fi

    export nR 

fi



#################################################################################
####################### DEFINE SUBJECTS TO RUN  ###################################
	
if ${runAll}; then
	find ${path2data} -maxdepth 1 -mindepth 1 -type d -printf '%f\n' \
	| sort > ${path2data}/${subj2run}	
fi 

#################################################################################
#################################################################################


## main
main() {

log "START running Connectivity Pipeline on the following subjects:"

IFS=$'\r\n' GLOBIGNORE='*' command eval 'SUBJECTS=($(cat ${path2data}/${subj2run}))'
log "subjects: ${SUBJECTS[@]}"

echo "##################"

# #### START PROCESSING SUBJECTS ###############

for SUBJdir in "${SUBJECTS[@]}"; do

    start=`date +%s`

    export SUBJ=${SUBJdir}
    
    log "Subject ${SUBJ}"

    export T1path="${path2data}/${SUBJ}/${configs_T1}"
    export DWIpath="${path2data}/${SUBJ}/${configs_DWI}"
    echo "============== T1path is ${T1path} =============="
    # echo "============== EXEDIR is ${EXEDIR} =============="

    # specify name of logfile written inside each subjects dir
    today=$(date +"%m_%d_%Y_%H_%M")
    export logfile_name="${path2data}/${SUBJ}/out_${today}"
    export QCfile_name="${path2data}/${SUBJ}/qc"
    export ERRfile_name="${path2data}/error_report"
 

    log "# ############################ T1_PREPARE_A #####################################"

        if $T1_PREPARE_A; then

            cmd="${EXEDIR}/src/scripts/t1_prepare_A.sh" # -d ${PWD}/inputdata/dwi.nii.gz \
            echo $cmd
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] ; then
                echoerr "problem at T1_PREPARE_A. exiting."
                dateTime=`date`
                echo "### $dateTime -" >> ${ERRfile_name}.log
                echo "$SUBJ ERROR -- problem at T1_PREPARE_A.  - " >> ${ERRfile_name}.log
                echo "###" >> ${ERRfile_name}.log 
                continue
            fi
        else 
            log "SKIP T1_PREPARE_A for subject $SUBJ"
        fi 

    ######################################################################################
    log "# ############################ T1_PREPARE_B #####################################"


        if $T1_PREPARE_B; then

            if [[ -d "$T1path" ]]; then 

                cmd="${EXEDIR}/src/scripts/t1_prepare_B.sh" # -np ${numParcs} -d ${PWD}/inputdata/dwi.nii.gz \
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at T1_PREPARE_B. exiting."
                    dateTime=`date`
                    echo "### $dateTime -" >> ${ERRfile_name}.log
                    echo "$SUBJ ERROR -- problem at T1_PREPARE_B.  - " >> ${ERRfile_name}.log
                    echo "###" >> ${ERRfile_name}.log                   
                    continue
                fi
                        
            else
                echo "T1 directory doesn't exist; skipping subject $SUBJ"
            fi
        else
            log "SKIP T1_PREPARE_B for subject $SUBJ"
        fi 

    ######################################################################################
    log "# ############################ fMRI_A ###########################################"


        if $fMRI_A; then

            if [[ -d "$T1path" ]]; then 

                cmd="${EXEDIR}/src/scripts/fMRI_A.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at fMRI_A. exiting."
                    dateTime=`date`
                    echo "### $dateTime -" >> ${ERRfile_name}.log
                    echo "$SUBJ ERROR -- problem at fMRI_A.  - " >> ${ERRfile_name}.log
                    echo "###" >> ${ERRfile_name}.log                    
                    continue
                fi
                        
            else
                echo "T1 directory doesn't exist; skipping subject $SUBJ"
            fi
        else
            log "SKIP fMRI_A for subject $SUBJ"
        fi 

    ######################################################################################
    # log "# ############################ fMRI_B ##########################################"

    ## Generates Figures... this is Matlab stand-alone script for now


    ######################################################################################
    log "# ############################ DWI_A ############################################"


        if $DWI_A; then

            if [[ -d "${DWIpath}" ]]; then 

                cmd="${EXEDIR}/src/scripts/DWI_A.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at DWI_A. exiting."
                    dateTime=`date`
                    echo "### $dateTime -" >> ${ERRfile_name}.log
                    echo "$SUBJ ERROR -- problem at DWI_A.  - " >> ${ERRfile_name}.log
                    echo "###" >> ${ERRfile_name}.log
                    continue
                fi
                        
            else
                echo "DWI directory doesn't exist; skipping subject $SUBJ"
            fi
        else
            log "SKIP DWI_A for subject $SUBJ"
        fi 

    ######################################################################################
    log "# ############################ DWI_B ############################################"


        if $DWI_B; then

            if [[ -d "${DWIpath}" ]]; then 

                cmd="${EXEDIR}/src/scripts/DWI_B.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at DWI_B. exiting."
                    dateTime=`date`
                    echo "### $dateTime -" >> ${ERRfile_name}.log
                    echo "$SUBJ ERROR -- problem at DWI_B.  - " >> ${ERRfile_name}.log
                    echo "###" >> ${ERRfile_name}.log
                    continue
                fi
                        
            else
                echo "DWI directory doesn't exist; skipping subject $SUBJ"
            fi
        else
            log "SKIP DWI_B for subject $SUBJ"
        fi 

    # ################################################################################
    # ################################################################################

        ## time it
        end=`date +%s`
        runtime=$((end-start))
        log "SUBJECT $SUBJ runtime: $runtime"

    echo "#################################################################################"
    echo "#################################################################################"
    
    dateTime=`date`
    echo "### $dateTime -" >> ${ERRfile_name}.log
    echo "$SUBJ COMPLETED -- runtime $runtime sec - " >> ${ERRfile_name}.log
    echo "###" >> ${ERRfile_name}.log

done    

} # main

# ################################################################################
# ################################################################################
# ## run it

main "$@"


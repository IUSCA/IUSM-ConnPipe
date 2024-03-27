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

##############################################################################

msg2file "# =========================================================="
msg2file "# 5.1 ICA-AROMA: Denoising. "
msg2file "# =========================================================="

if [[ ! -e "${EPIrun_out}/4_epi.nii.gz" ]]; then  

    log "WARNING File ${EPIrun_out}/4_epi.nii.gz does not exist. Skipping further analysis"
    exit 1 
fi 

AROMApath="${EPIrun_out}/AROMA"

if [[ -d "${AROMApath}" ]]; then
    # rename existing directory before creating a new one
    today=$(date +"%m_%d_%Y_%H_%M")
    cmd="mv ${AROMApath} ${AROMApath}_${today}"
    log $cmd
    eval $cmd
fi

cmd="mkdir ${AROMApath}"
log "AROMA - creating directory"
log --no-datetime $cmd
eval $cmd

AROMAreg_path="${AROMApath}/registration"
cmd="mkdir ${AROMAreg_path}"
log "AROMAreg - creating directory"
log --no-datetime $cmd
eval $cmd 

log --no-datetime "## Generating Inputs:"

fileMat="${EPIrun_out}/epi_2_T1_bbr_dof6.mat"
if [[ ! -e "${fileMat}" ]]; then
    log "WARNING Linear EPI -> T1 transformation not found. Please set the flag flags_EPI_RegT1=true"
    exit 1
else
    log --no-datetime "#### EPI to T1 linear transformation found."
fi

log "#### T1 to MNI 2mm nonlinear transform"
fileT1="${T1path}/T1_brain.nii.gz"
fileMNI2mm="${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz"
filedof12mat="${AROMAreg_path}/T1_2_MNI2mm_dof12.mat"
filedof12img="${AROMAreg_path}/rT1_dof12_2mm.nii.gz"

cmd="flirt -in ${fileT1} \
-ref ${fileMNI2mm} \
-omat ${filedof12mat} \
-dof 12 -cost mutualinfo \
-interp spline -out ${filedof12img}"
log --no-datetime $cmd
eval $cmd 

fileWarpImg="${AROMAreg_path}/rT1_warped_2mm.nii.gz"
fileWarpField="${AROMAreg_path}/T1_2_MNI2mm_warpfield.nii.gz" 

cmd="fnirt \
--in=${fileT1} \
--ref=${fileMNI2mm} \
--aff=${filedof12mat} \
--iout=${fileWarpImg} \
--cout=${fileWarpField}"
log $cmd
eval $cmd 

# 6mm FWHM EPI data smoothing
log "### Smoothing EPI data by 6mm FWHM"
fileEPI="${EPIrun_out}/4_epi.nii.gz"
fileSmooth="${AROMApath}/s6_4_epi.nii.gz" 

cmd="fslmaths ${fileEPI} \
-kernel gauss 2.547965400864057 \
-fmean ${fileSmooth}"
log --no-datetime $cmd
eval $cmd 


# mcFLIRT realignment parameters 
log "#### mcFLIRT realignment parameters"

fileMovePar="${EPIrun_out}/motion.txt"
if [[ ! -e "${fileMovePar}" ]]; then
    log "WARNING Movement parameters from mcFLIRT not found. \
    Please set the flag flags_EPI_MotionCorr=true. Exiting..."
    exit 1
else
    log --no-datetime "#### mcFLIRT motion file found."
fi 

log "## Starting ICA-AROMA"

cmd="which python"
echo $cmd
eval $cmd

AROMAout="${AROMApath}/AROMA-output"

if [[ -d "${AROMAout}" ]]; then
    cmd="rm -rf ${AROMAout}"
    log --no-datetime $cmd
    eval $cmd     
fi

# set number of components if user doesn't want automatic estimation
if [[ ! -z "${config_AROMA_dim}" ]]; then

    re='^[0-9]+$'

    if [[ ${config_AROMA_dim} =~ $re ]] ; then  # check that it is a number 
        AROMA_dim="-dim ${config_AROMA_dim}"
    else
        log "WARNING config_AROMA_dim should be a number; running AROMA with automatic estimation of number of components."
        AROMA_dim=" "
    fi
else
    AROMA_dim=" "
fi 

cmd="${run_ICA_AROMA} \
-in ${fileSmooth} \
-out ${AROMAout} \
-mc ${fileMovePar} \
-affmat ${fileMat} \
-warp ${fileWarpField} ${AROMA_dim}"
log $cmd 
eval $cmd
# out=`$cmd`
# log "$out"

if [[ ! -e "${AROMAout}/denoised_func_data_nonaggr.nii.gz" ]]; then

    log "# WARNING AROMA output file not found! Exiting..."
    log --no-datetime "# Posible causes of failure:"
    log --no-datetime "    - Files are not in AROMA directoy, but in melodic ICA direcotry"
    log --no-datetime "    - There are too many components and AROMA did not filter porperly. If this is the case then fslfilt can be ran manually. "

else
    log "### ICA-AROMA Done."
fi 

# compute percent variance removed from the data
ICstats="${AROMAout}/melodic.ica/melodic_ICstats"
motionICs="${AROMAout}/classified_motion_ICs.txt"

cmd="python ${EXEDIR}/src/func/percent_variance.py \
    ${ICstats} ${motionICs}"
log --no-datetime $cmd
eval $cmd


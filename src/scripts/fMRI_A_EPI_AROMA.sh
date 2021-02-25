
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

function f_percent_variance() {
fIn1="$1" fIn2="$2" python - <<END
import os
import numpy as np

fIn1=os.environ['fIn1']
#print("fIn1: ", fIn1)

fIn2=os.environ['fIn2']
#print("fIn2: ", fIn2)

ICstats = np.loadtxt(fIn1)
#print(ICstats)
#print(ICstats.shape)

motionICs = np.loadtxt(fIn2, delimiter=",",dtype=np.int32)
#print(motionICs)


peVar = np.zeros(len(motionICs))
ptVar = np.zeros(len(motionICs))


for i in range(0,len(motionICs)):
    ind = motionICs[i]
    peVar[i] = ICstats[ind-1,0]
    ptVar[i] = ICstats[ind-1,1]

peVar = np.sum(peVar)
ptVar = np.sum(ptVar)

print("%.2f percent of explained variance in removed motion components" % peVar)
print("%.2f percent of total variance in removed motion components" % ptVar)


END
}

##############################################################################


echo "# =========================================================="
echo "# 5.1 ICA-AROMA: Denoising. "
echo "# =========================================================="

if [[ ! -e "${EPIpath}/4_epi.nii.gz" ]]; then  

    log "WARNING File ${EPIpath}/4_epi.nii.gz does not exist. Skipping further analysis"
    exit 1 
fi 

AROMApath="${EPIpath}/AROMA"

if [[ ! -d "${AROMApath}" ]]; then
    cmd="mkdir ${AROMApath}"
    log "AROMA - creating directory"
    log $cmd
    eval $cmd 
fi 

AROMAreg_path="${AROMApath}/registration"

if [[ ! -d "${AROMAreg_path}" ]]; then
    cmd="mkdir ${AROMAreg_path}"
    log "AROMAreg - creating directory"
    log $cmd
    eval $cmd 
fi 

echo "## Generating Inputs"
echo "#### EPI to T1 linear transform"

fileMat="${EPIpath}/epi_2_T1_bbr_dof6.mat"
if [[ ! -e "${fileMat}" ]]; then
    log "WARNING Linear EPI -> T1 transformation not found. Please set the flag flags_EPI_RegT1=true"
    exit 1
fi 

echo "#### T1 to MNI 2mm nonlinear transform"

fileT1="${T1path}/T1_brain.nii"
fileMNI2mm="${pathFSLstandard}/MNI152_T1_2mm_brain.nii.gz"
filedof12mat="${AROMAreg_path}/T1_2_MNI2mm_dof12.mat"
filedof12img="${AROMAreg_path}/rT1_dof12_2mm.nii.gz"

if [[ ! -e "${filedof12mat}" ]]; then

    cmd="flirt -in ${fileT1} \
    -ref ${fileMNI2mm} \
    -omat ${filedof12mat} \
    -dof 12 -cost mutualinfo \
    -interp spline -out ${filedof12img}"

    log $cmd
    eval $cmd 

else
    echo "### Using existing T1->MNI_2mm linear transformation"
fi 

fileWarpImg="${AROMAreg_path}/rT1_warped_2mm.nii.gz"
fileWarpField="${AROMAreg_path}/T1_2_MNI2mm_warpfield.nii.gz" 

if [[ ! -e "${fileWarpField}" ]]; then

    cmd="fnirt \
    --in=${fileT1} \
    --ref=${fileMNI2mm} \
    --aff=${filedof12mat} \
    --iout=${fileWarpImg} \
    --cout=${fileWarpField}"
    log $cmd
    eval $cmd 

else
    echo "### Using existing T1->MNI_2mm nonlinear transformation"
fi  

# 6mm FWHM EPI data smoothing
echo "### Smoothing EPI data by 6mm FWHM"
fileEPI="${EPIpath}/4_epi.nii.gz"
fileSmooth="${AROMApath}/s6_4_epi.nii.gz" 

if [[ ! -e "${fileSmooth}" ]]; then

    cmd="fslmaths ${fileEPI} \
    -kernel gauss 2.547965400864057 \
    -fmean ${fileSmooth}"
    log $cmd
    eval $cmd 

else
    echo "### Using existing smoothed s6_4_epi data"
fi        

# mcFLIRT realignment parameters 
echo "#### mcFLIRT realignment parameters"

fileMovePar="${EPIpath}/motion.txt"
if [[ ! -e "${fileMovePar}" ]]; then
    log "WARNING Movement parameters from mcFLIRT not found. \
    Please set the flag flags_EPI_MotionCorr=true. Exiting..."
    exit 1
fi 

echo "## Starting ICA-AROMA"

AROMAout="${AROMApath}/AROMA-output"

if [[ -d "${AROMAout}" ]]; then
    cmd="rm -rf ${AROMAout}"
    log $cmd
    eval $cmd     
fi

# set number of components if user doesn't want automatic estimation
if [[ ! -z "${flag_AROMA_dim}" ]]; then

    re='^[0-9]+$'

    if [[ ${flag_AROMA_dim} =~ $re ]] ; then  # check that it is a number 
        AROMA_dim="-dim ${flag_AROMA_dim}"
    else
        log "WARNING flag_AROMA_dim should be a number; running AROMA with automatic estimation of number of components"
        AROMA_dim=" "
    fi
else
    AROMA_dim=" "
fi 

#cmd="ICA_AROMA.py \

cmd="python ${ICA_AROMA_path}/ICA_AROMA.py \
-in ${fileSmooth} \
-out ${AROMAout} \
-mc ${fileMovePar} \
-affmat ${fileMat} \
-warp ${fileWarpField} ${AROMA_dim}"
log $cmd 
out=`$cmd`
log "$out"

if [[ ! -e "${AROMAout}/denoised_func_data_nonaggr.nii.gz" ]]; then

    echo "# WARNING AROMA output file not found! Exiting..."
    echo "# Posible causes of failure:"
    echo "    - Files are not in AROMA directoy, but in melodic ICA direcotry"
    echo "    - There are too many components and AROMA did not filter porperly. If this is the case then fslfilt can be ran manually. "

else
    echo "### ICA-AROMA Done."
fi 


# compute percent variance removed from the data
ICstats="${AROMAout}/melodic.ica/melodic_ICstats"
motionICs="${AROMAout}/classified_motion_ICs.txt"
f_percent_variance ${ICstats} ${motionICs}
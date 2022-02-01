               
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

# source ${EXEDIR}/src/func/bash_funcs.sh

############################################################################### 

echo " ==========================================="
echo "      Transform EPI -> MNI "
echo " ==========================================="

## This function shuld work as a stand-alone func that can 
## be used outside of the pipeline. 
## Needs FSL to be loaded as an HPC module -> ${FSLDIR} variable *must* be defined

# # how to call this funciton and apply transformations 
# transform_epi2MNI.sh ${EPIpath} ${T1reg} ${fileIn} ${fileOut}"

### TODO - ADD ARGUMENT FOR 1 OR 2 MM

EPIpath=$1
T1reg=$2
fileIn=$3
fileOut=$4
MNIres=$5

echo "EPIpath is -- ${EPIpath}"
echo "T1reg is -- ${T1reg}"
echo "fileIn is -- ${fileIn}"
echo "fileOut is -- ${fileOut}"
echo "MNI resolution is -- ${MNIres}"

fileMat="${EPIpath}/epi_2_MNI_final.mat"
fileWarp="${T1reg}T12MNI_warp.nii.gz"

if [[ "${MNIres}" == "2" ]]; then 
    # 2mm resolution
    path2MNIref="${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz"
# elif [[ ${MNIres} -eq "2" ]]; then 
else # use 1mm resolution to ensure that scaling factor = desired res size. 
    # 1mm resolution
    path2MNIref="${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz"
fi 

# check that all needed files exist
# ref images
if [[ ! -e ${path2MNIref} ]]; then
    echo "ERROR  - ${path2MNIref} not found. Exiting..."
    exit 1
fi

# T12MNI_warp
if [[ ! "${T1reg}/T12MNI_warp.nii.gz" ]]; then
    echo "ERROR  - ${T1reg}/T12MNI_warp.nii.gz not found. Exiting..."
    exit 1
fi

# epi_2_MNI
if [[ ! "${EPIpath}/epi_2_MNI_final.mat" ]]; then
    echo "ERROR  - ${EPIpath}/epi_2_MNI_final.mat not found. Exiting..."
    exit 1
fi

cmd="applywarp -i ${fileIn} \
    -o ${fileOut} \
    -r ${path2MNIref} \
    -w ${T1reg}/T12MNI_warp.nii.gz \
    --premat=${EPIpath}/epi_2_MNI_final.mat \
    --interp=nn"
echo $cmd
eval $cmd 



               
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


## This function shuld work as a stand-alone func that can 
## be used outside of the pipeline. 
## Needs FSL to be loaded as an HPC module -> ${FSLDIR} variable *must* be defined

# # how to call this funciton and apply transformations 
# resample_MNIres.sh ${fileIn} ${fileOut} ${resIn} ${resOut}"

### TODO - ADD ARGUMENT FOR 1 OR 2 MM

fileIn=$1
fileOut=$2
resIn=$3
resOut=$4


echo " ==============================================================="
echo "      Resample image from ${resIn}mm res to ${resOut}mm resolution "
echo " ==============================================================="

echo "fileIn is -- ${fileIn}"
echo "fileOut is -- ${fileOut}"
echo "resIn is -- ${resIn}"
echo "resOut is -- ${resOut}"

if [[ ${resIn} -eq "2" ]]; then 
    # 2mm resolution
    path2MNIref="${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz"
elif [[ ${resIn} -eq "1" ]]; then 
    # 1mm resolution
    path2MNIref="${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz"
fi 

scaling=$(bc <<< "scale=1 ; ${resOut} / ${resIn}")
echo "Scaling factor is ${scaling}"

# check that all needed files exist
if [[ ! -e ${fileIn} ]]; then
    echo "ERROR  - ${fileIn} not found. Exiting..."
    exit 1
fi


cmd="flirt -in ${fileIn}\
    -ref ${path2MNIref}\
    -out ${fileOut}\
    -applyisoxfm ${scaling}"
echo $cmd
eval $cmd 

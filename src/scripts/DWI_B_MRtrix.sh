
#!/bin/bash
#
# Script: f_preproc_DWI.m adaptaion from Matlab script 
#

###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

############################################################################### 



############################################################################### 


echo "=================================="
echo "2. MRtrix Streamline Tractography"
echo "=================================="

# set paths
path_DWI_EDDY="${DWIpath}/EDDY"
path_DWI_DTIfit="${DWIpath}/DTIfit"
path_DWI_mrtrix="${DWIpath}/MRtrix"


if [[ ! -d "${path_DWI_mrtrix}" ]]; then
    cmd="mkdir ${path_DWI_mrtrix}"
    log $cmd
    eval $cmd
fi 

## Response Function Estimation
echo "2.1 Estimating Response function"

voxelsOUT="${path_DWI_mrtrix}/csd_selected_voxels.nii.gz"
maskIN="${path_DWI_EDDY}/b0_brain_mask.nii.gz"
bvecIN="${path_DWI_EDDY}/eddy_output.eddy_rotated_bvecs"
bvalIN="${path_DWI_DTIfit}/3_DWI.bval"
dataIN="${path_DWI_EDDY}/eddy_output.nii.gz"

fileResponse="${path_DWI_mrtrix}/tournier_response.txt"
    # !!! CONFIG NEEDS ADDED:
    # tournier is one of several algorith options; best choice can vary
    # depending on data quality (i.e. number of shells and directions)
cmd="dwi2response tournier \
    -voxels ${voxelsOUT} \
    -force -mask ${maskIN} \
    -fslgrad ${bvecIN} ${bvalIN} ${dataIN} ${fileResponse}"
log $cmd
eval $cmd 

## constrained shperical deconvolution
echo "2.2 Constrained Spherical Deconvolution"

fileFOD="${path_DWI_mrtrix}/csd_fod.mif"
    # # !!! CONFIG NEEDS ADDED:
    # # csd is one possible algorithm for csd estimation; best one is data dependent
    # # additional options may be needed for multi-shell data
cmd="dwi2fod csd -force \
    -fslgrad ${bvecIN} ${bvalIN} 
    -mask ${maskIN} ${dataIN} ${fileResponse} ${fileFOD}"
log $cmd
eval $cmd 

## ACT tissue-type volume generation
echo "2.3 Anatomically Constrained Tractography"

brainIN="${DWIpath}/rT1_dof6.nii.gz"
file5tt="${path_DWI_mrtrix}/fsl5tt.nii.gz"

    # act needs distortion corrected data; should work with no dist corr,
    # but with nonlinear reg, but I havent tried it.
cmd="5ttgen fsl -force -premasked ${brainIN} ${file5tt}"
log $cmd
eval $cmd 

## generate streamlines
echo "2.4 Generating Streamlines"
    # CONFIG: 10million streamlines could be user set to other numbers
fileStreamlines="${path_DWI_mrtrix}/10m_streamlines.tck"

    # CONFIG: 10M can be changed
    # CONFIG: iFOD2 can be changed to other algorithms, but best one depends on the data
    # CONFIG : -seed_dynamic can be switched out for other options
    # CONFIG : act can be options if data does not allow it. 
    # There may be other options withing tckgen that could be useful, this
    # is just basic usage. 
cmd="tckgen ${fileFOD} ${fileStreamlines} \
    -act ${file5tt} -crop_at_gmwmi \
    -algorithm iFOD2 -seed_dynamic ${fileFOD} -select 10M"
       
log $cmd
eval $cmd 

## set min-max length boundaries
echo "2.4.1 Apply Length Filter"

fileStreamlines2="${path_DWI_mrtrix}/10m_10-200l_streamlines.tck"
    # CONFIG: minimum and maximum streamline lengths can be user set
cmd="tckedit -force -minlength 10 -maxlength 200 ${fileStreamlines} ${fileStreamlines2}"
log $cmd
eval $cmd 

if [[ -f "${fileStreamlines2}" ]]; then
    cmd="rm -f ${fileStreamlines}"
    log $cmd
    eval $cmd
else
    log "WARNING file ${fileStreamlines2} not generated. Exiting..."
    exit 1
fi


## filter streamlines
echo "2.5 Running SIFT Filtering"

fileFiltStreamlines="${path_DWI_mrtrix}/1m_sift_streamlines.tck"
    # For SIFT ACT is pretty much a requirement, so if ACT cant be done, then 
    # sift shouldnt be done and tckgen can be done with less streamlines.
cmd="tcksift -force -act ${file5tt} \
    -term_number 1M ${fileStreamlines2} ${fileFOD} ${fileFiltStreamlines}"
log $cmd
eval $cmd 
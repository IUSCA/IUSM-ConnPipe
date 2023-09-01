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


if [[ ! -d "${path_DWI_mrtrix}" ]]; then
    cmd="mkdir ${path_DWI_mrtrix}"
    log $cmd
    eval $cmd
fi 

# check paths
log "path_DWI_EDDY is ${path_DWI_EDDY}"
log "path_DWI_DTIfit is ${path_DWI_DTIfit}"
log "path_DWI_mrtrix is ${path_DWI_mrtrix}"

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
    -nthreads ${configs_DWI_nthreads} \
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
    -fslgrad ${bvecIN} ${bvalIN} \
    -nthreads ${configs_DWI_nthreads} \
    -mask ${maskIN} ${dataIN} ${fileResponse} ${fileFOD}"
log $cmd
eval $cmd 

## ACT tissue-type volume generation
echo "2.3 Anatomically Constrained Tractography"

brainIN="${DWIpath}/rT1_dof6.nii.gz"
file5tt="${path_DWI_mrtrix}/fsl5tt.nii.gz"

    # act needs distortion corrected data; should work with no dist corr,
    # but with nonlinear reg, but I havent tried it.
cmd="5ttgen fsl -force -nthreads ${configs_DWI_nthreads} -premasked ${brainIN} ${file5tt}"
log $cmd
eval $cmd 

## generate streamlines
echo "2.4 Generating Streamlines"
#configs_DWI_step_sizes=(0.625 1.25 1.875 2.5 )
configs_DWI_step_sizes=(1 1.5 2)
configs_DWI_max_angles=(30 45 60)
fileStreamlines="${path_DWI_mrtrix}/combo_streamlines.tck"

if [[ ! -e ${fileStreamlines} ]] ; then 
    combo_list="" 
    echo $fileStreamlines

    for (( sDx=0 ; sDx<${#configs_DWI_step_sizes[@]} ; sDx++ )) ; do
       # echo ${configs_DWI_step_sizes[sDx]}
        for (( mDx=0 ; mDx<${#configs_DWI_max_angles[@]} ; mDx++ )) ; do  
          #  echo ${configs_DWI_max_angles[mDx]}  
            l_step=${configs_DWI_step_sizes[$sDx]}
            l_angle=${configs_DWI_max_angles[$mDx]}

            echo "$sDx $mDx"
            echo "running step size: $l_step, angle size: $l_angle"

            outstr=$(echo "ss$l_step-ma$l_angle" | sed s,\\.,p,)
            outFile=${path_DWI_mrtrix}/tracks_${outstr}.tck
            
            trk_start=`date +%s`
            if [[ ${configs_DWI_seeding} == "dyn" ]]; then
                cmd="tckgen ${fileFOD} ${outFile} \
                    -act ${file5tt} \
                    -seed_dynamic ${fileFOD} \
                    -angle $l_angle \
                    -step $l_step \
                    -minlength 10.0 \
                    -maxlength 220.0 \
                    -power 0.33 \
                    -backtrack \
                    -crop_at_gmwmi \
                    -max_attempts_per_seed 150 \
                    -downsample 2 \
                    -algorithm iFOD2 \
                    -select 1M \
                    -nthreads ${configs_DWI_nthreads}"
            elif [[ ${configs_DWI_seeding} == "wm" ]]; then
                seedImage="${DWIpath}/rT1_WM_mask.nii.gz"
                cmd="tckgen ${fileFOD} ${outFile} \
                    -act ${file5tt} \
                    -seeds ${configs_DWI_Nseeds} \
                    -seed_image ${seedImage} 
                    -angle $l_angle \
                    -step $l_step \
                    -minlength 10.0 \
                    -maxlength 220.0 \
                    -power 0.33 \
                    -backtrack \
                    -crop_at_gmwmi \
                    -max_attempts_per_seed 150 \
                    -downsample 2 \
                    -algorithm iFOD2 \
                    -nthreads ${configs_DWI_nthreads}"
                    echo $cmd
            fi
            log $cmd
            eval $cmd 
            combo_list="$combo_list ${outFile}"

            trk_end=$(date +%s)
            lt="loop time: $(( trk_end - trk_start ))"
			log $lt
			#eval $lt

        done # angle
    done # step

    #combine
    cmd="tckedit \
		-force \
		-nthreads ${configs_DWI_nthreads} \
		$combo_list \
		${fileStreamlines}"

	echo $cmd
	log $cmd
	eval $cmd

else
    echo "combo_streamlines.tck exists. No tractography done."
fi
## purge the intermediate tracking files
log "rm ${combo_list}"
eval "rm ${combo_list}"

## filter streamlines
echo "2.5 Running SIFT Filtering"

fileFiltStreamlines="${path_DWI_mrtrix}/1m_sift_streamlines.tck"
    # For SIFT ACT is pretty much a requirement, so if ACT cant be done, then 
    # sift shouldnt be done and tckgen can be done with less streamlines.
cmd="tcksift \
     -force \
     -act ${file5tt} \
     -nthreads ${configs_DWI_nthreads} \
	 -term_number 1M \
    ${fileStreamlines} ${fileFOD} ${fileFiltStreamlines}"
log $cmd
eval $cmd 

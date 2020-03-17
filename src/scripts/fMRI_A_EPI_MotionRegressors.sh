
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

function f_load_motion_reg() {
path="$1" numReg="$2" ${python3_7} - <<END
import os
import numpy as np

EPIpath=os.environ['path']

numReg=int(os.environ['numReg'])

# load motion regressors
fname=''.join([EPIpath,'/motion.txt'])
motion = np.loadtxt(fname)
[rows,columns] = motion.shape

# derivatives of 6 motion regressors
motion_deriv = np.zeros((rows,columns))

for i in range(columns):
    m = motion[:,i]
    m_deriv = np.diff(m)
    motion_deriv[1:,i] = m_deriv

fname=''.join([EPIpath,'/HMPreg/motion_deriv.txt'])
np.savetxt(fname, motion_deriv,fmt='%2.7f')
fname=''.join([EPIpath,'/HMPreg/motion.txt'])
np.savetxt(fname, motion,fmt='%2.7f')

if numReg == 24:
    motion_sq = np.power(motion,2)
    motion_deriv_sq = np.power(motion_deriv,2)


fname=''.join([EPIpath,'/HMPreg/motion_sq.txt'])
np.savetxt(fname, motion_sq,fmt='%2.7f')
fname=''.join([EPIpath,'/HMPreg/motion_deriv_sq.txt'])
np.savetxt(fname, motion_deriv_sq,fmt='%2.7f')


END
}

##############################################################################

## 7. MOTION AND OUTLIER REGRESSORS


#fileIn=${EPIpath}/4_epi.nii.gz

if [[ ! -e "${EPIpath}/0_epi.nii.gz" ]]; then  

    log "WARNING -  ${EPIpath}/4_epi.nii.gz does not exist. Skipping further analysis..."
    exit 1        

else


    log "## Working on 0_epi.nii.gz"
    cmd="fslval ${fileIn} pixdim4"
    log $cmd
    TR=`$cmd`
    log "# TR is $TR "
    #TR=`echo $out | awk -F' ' '{ print $2}'`
    #echo "Header extracted TR is: ${TR}" 

    # dropTRs=$(bc <<< "scale=0 ; ($configs_EPI_scrubtime / $TR) + 1")
    # echo "dropTRs is ${dropTRs}"

    dropTRs=`python -c "from math import ceil; print(ceil($configs_EPI_scrubtime / $TR))"`
    log "# dropTRs is ${dropTRs}"

    cmd="fslval ${fileIn} dim4"
    log $cmd
    nvols=`$cmd`
    log "# nvols is $nvols" 

    TR_init=$(bc <<< "scale=0 ; $dropTRs+1")
    TR_end=$(bc <<< "scale=0 ; $nvols-${dropTRs}")

    log "TR_init = $TR_init"
    log "TR_end = $TR_end"    

fi 

# if [[ ${flags_EPI_GS} -eq 1 ]]; then
    
#     epiGS_path="${EPIpath}/GSreg_yes"
#     GSreg_name="GSreg\_yes"  

# elif [[ ${flags_EPI_GS} -eq 0 ]]; then

#     epiGS_path="${EPIpath}/GSreg_no"
#     GSreg_name="GSreg\_no"

# else

#     log "WARNING flags_EPI_GS not specified. Exiting..."
#     exit 1

# fi 

# if [[ ! -d ${epiGS_path} ]]; then 
#     cmd="mkdir ${epiGS_path}"
#     log $cmd
#     eval $cmd 
# fi   


# echo "# =========================================================="
# echo "# 7. Motion and Outlier Regressors. "
# echo "# =========================================================="

# file2read="${EPIpath}/6_epi.nii.gz"

# out=`python -c "import nibabel as nib; resting=nib.load('$file2read'); \
# resting_vol=resting.get_data(); [sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape; \
# print(sizeX,sizeY,sizeZ,numTimePoints)"`

# #echo "out is $out"

# IFS=' ' read sizeX sizeY sizeZ numTimePoints <<< $out
# # sizeX=$(echo $sizeX | cut -c2- )
# # numTimePoints=$(echo $numTimePoints | rev | cut -c2- | rev )
# log "# sizeX = $sizeX"
# log "# sizeY = $sizeY"
# log "# sizeZ = $sizeZ"
# log "# numTImePoints = $numTimePoints"

# if [[ ${numTimePoints} -ne ${nvols} ]]; then
#     log "WARNING Number of time points is inconsistent. Exiting..."
#     exit 1
# fi

# # -------------------------------------------------------------------------------
# ## load 6 motion regressors
# f_load_motion_reg $EPIpath

# # -------------------------------------------------------------------------------

###!!!!!!!!!!!!!! Jan 22, 2020  - this was moved to fMRI_A_EPI_MotionCorr.sh

# fileMask="${EPIpath}/1_epi_brain_mask.nii.gz"

# ## Frame Displacement regressor
# log "# Computing DF regressor"
# # example: fsl_motion_outliers \
# # -i 4_drafREST1.nii.gz \
# # -o motionOutputFD.txt \
# # -s motionMetricsFD.txt \
# # -p motionMetricsFD.png --fd

# metric="fd"
# fileIn="${EPIpath}/1_epi.nii.gz"
# fileOut="${epiGS_path}/motionRegressor_${metric}"
# fileMetrics="${epiGS_path}/motionMetric_${metric}"

# if [[ -e ${fileOut} ]]; then
#     cmd="rm ${fileOut}"
#     log $cmd 
#     eval $cmd 
# fi

# if [[ -e ${fileMetrics} ]]; then
#     cmd="rm ${fileMetrics}"
#     log $cmd 
#     eval $cmd 
# fi

# filePlot="${epiGS_path}/motionPlot_${metric}"

# cmd="fsl_motion_outliers -i ${fileIn} \
# -o ${fileOut} \
# -s ${fileMetrics} \
# -p ${filePlot} \
# --${metric} --thresh=${configs_EPI_FDth} -m ${fileMask}"
# log $cmd
# eval $cmd 

# if [[ -e ${fileMetrics} ]] && [[ -z ${configs_EPI_FDth} ]]; then
#     out=`python -c "import numpy as np; metrics = np.loadtxt('${fileMetrics}') \
#     scrubbing_fd = metrics < ${configs_EPI_FDth}
#     print(np.count_nonzero(scrubbing_fd))"`
# fi












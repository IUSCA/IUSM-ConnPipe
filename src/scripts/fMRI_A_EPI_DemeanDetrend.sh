
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

function demean_detrend() {
path="$1" ${python3_7} - <<END
import os
import nibabel as nib
import numpy as np
from scipy import signal

EPIpath=os.environ['path']
#print(EPIpath)

fname=''.join([EPIpath,'/AROMA/AROMA-output/denoised_func_data_nonaggr.nii.gz'])
resting=nib.load(fname)  
resting_vol=resting.get_data()
print(resting.shape)
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape

# read brain mask

fname=''.join([EPIpath,'/rT1_brain_mask.nii.gz'])
volBrain=nib.load(fname)  
print(volBrain.shape)
volBrain_vol=volBrain.get_data()

fname=''.join([EPIpath,'/2_epi_meanvol_mask.nii.gz'])
volRef=nib.load(fname)  
print(volRef.shape)
volRef_vol=volRef.get_data()

volBrain_vol = (volBrain_vol > 0) & (volRef_vol != 0)
print(volBrain_vol.shape)

fileOut=''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
volBrain = nib.Nifti1Image(volBrain_vol.astype(np.float32),volBrain.affine,volBrain.header)
nib.save(volBrain,fileOut)

# demean and detrend

for i in range(0,sizeX):
    for j in range(0,sizeY):
        for k in range(0,sizeZ):
            if volBrain_vol[i,j,k] > 0:
                TSvoxel = resting_vol[i,j,k,:].reshape(numTimePoints,1)
                TSvoxel_detrended = signal.detrend(TSvoxel-np.mean(TSvoxel),type='linear')
                resting_vol[i,j,k,:] = TSvoxel_detrended.reshape(1,1,1,numTimePoints)
    if i % 25 == 0:
        print(i/sizeX)  ## change this to percentage progress 

fileOut2=''.join([EPIpath,'/6_epi.nii.gz'])
resting_detrended = nib.Nifti1Image(resting_vol.astype(np.float32),resting.affine,resting.header)
nib.save(resting_detrended,fileOut2)

END
}


###################################################################################


echo "# =========================================================="
echo "# 6. Demean and Detrend. "
echo "# =========================================================="

if [[ ! -e "${EPIpath}/AROMA/AROMA-output/denoised_func_data_nonaggr.nii.gz" ]]; then  

    log "WARNING - No AROMA output found."

    if [[ -e "${EPIpath}/4_epi.nii.gz" ]]; then  

        log "## Working on 4_epi volume"
        fileIn="${EPIpath}/4_epi.nii.gz"

    else
        log "WARNING -  No AROMA or 4_epi volume exists. Exiting..."
        exit 1        
    fi  

else
    log "## Working on AROMA otuput volume"
    fileIn="${EPIpath}/AROMA/AROMA-output/denoised_func_data_nonaggr.nii.gz"
fi 

# read data, demean and detrend
demean_detrend ${EPIpath}

# fill holes in the brain mask, without changing FOV
fileOut="${EPIpath}/rT1_brain_mask_FC.nii.gz"
cmd="fslmaths ${fileOut} -fillh ${fileOut}"
log $cmd
eval $cmd 

fileOut2="${EPIpath}/6_epi.nii.gz"
cmd="fslmaths ${fileOut2} -mas ${fileOut} ${fileOut2}"
log $cmd
eval $cmd 

# cmd="python ${EXEDIR}/src/scripts/test_python_scripts.py"
# log $cmd
# eval $cmd



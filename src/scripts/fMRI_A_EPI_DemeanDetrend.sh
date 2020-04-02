
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
fileIn="$1" fileOut="$2" python - <<END
import os
import nibabel as nib
import numpy as np
from scipy import signal
from pathlib import Path


fileIn=os.environ['fileIn']
fileOut=os.environ['fileOut']

data = np.load(fileIn) 

resting_vol=data['resting_vol']
print(resting_vol.shape)
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape

resid=data['resid']
volBrain_vol=data['volBrain_vol']

# demean and detrend

for pc in range(0,len(resid)):
    for i in range(0,sizeX):
        for j in range(0,sizeY):
            for k in range(0,sizeZ):
                if volBrain_vol[i,j,k] > 0:
                    TSvoxel = resid[pc][i,j,k,:].reshape(numTimePoints,1)
                    TSvoxel_detrended = signal.detrend(TSvoxel-np.mean(TSvoxel),type='linear')
                    resid[pc][i,j,k,:] = TSvoxel_detrended.reshape(1,1,1,numTimePoints)
        if i % 25 == 0:
            print(i/sizeX)  ## change this to percentage progress 


## save data 
np.savez(fileOut,resid=resid)
print("Saved demeaned and detrended residuals")

END
}


###################################################################################


echo "# =========================================================="
echo "# 6. Demean and Detrend. "
echo "# =========================================================="


PhReg_path="${EPIpath}/${regPath}"
fileIn="${PhReg_path}/NuisanceRegression_${nR}_output.npz"
fileOut="${PhReg_path}/NuisanceRegression_${nR}_output_dmdt.npz"

if [[ ! -e "${PhReg_path}/NuisanceRegression_${nR}_output.npz" ]]; then  
    log " WARNING No output found for batch defined nuisance regressed data for ${EPIpath}"
    exit 1    
fi 

# read data, demean and detrend
demean_detrend ${fileIn} ${fileOut}

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




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
from scipy.io import savemat


fileIn=os.environ['fileIn']
fileOut=os.environ['fileOut']

data = np.load(fileIn) 

resting_vol=data['resting_vol']
print("resting_vol.shape: ",resting_vol.shape)
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape

resid=data['resid']
volBrain_vol=data['volBrain_vol']


# demean and detrend

print("len(resid): ",len(resid))
print("resid.shape: ",resid.shape)


for pc in range(0,len(resid)):
    for i in range(0,sizeX):
        for j in range(0,sizeY):
            for k in range(0,sizeZ):
                if volBrain_vol[i,j,k] > 0:
                    TSvoxel = resid[pc][i,j,k,:].reshape(numTimePoints,1)
                    #TSvoxel_detrended = signal.detrend(TSvoxel-np.mean(TSvoxel),type='linear')
                    TSvoxel_detrended = signal.detrend(TSvoxel-np.mean(TSvoxel),axis=0,type='linear')
                    resid[pc][i,j,k,:] = TSvoxel_detrended.reshape(1,1,1,numTimePoints)
                # else:
                #     resid[pc][i,j,k,:] = np.zeros((1,1,1,numTimePoints));
        if i % 25 == 0:
            print(i/sizeX)  ## change this to percentage progress 
    
    # zero-out voxels that are outside the GS mask
    for t in range(0,numTimePoints):
        rv = resid[pc][:,:,:,t]
        rv[volBrain_vol==0]=0
        resid[pc][:,:,:,i] = rv


## save data 
np.savez(fileOut,resid=resid)
print("Saved demeaned and detrended residuals")

print("savign MATLAB file ", fileOut)
mdic = {"resid" : resid}
savemat(fileOut, mdic)

END
}


###################################################################################


log "# =========================================================="
log "# 6. Demean and Detrend. "
log "# =========================================================="


PhReg_path="${EPIpath}/${regPath}"
fileIn="${PhReg_path}/NuisanceRegression_${nR}_output.npz"
fileOut="${PhReg_path}/NuisanceRegression_${nR}_output_dmdt.npz"

if [[ ! -e "${PhReg_path}/NuisanceRegression_${nR}_output.npz" ]]; then  
    log " WARNING No output found for batch defined nuisance regressed data for ${EPIpath}"
    exit 1    
fi 

# read data, demean and detrend
demean_detrend ${fileIn} ${fileOut}


## OLD VERSION OF PIPELINE
# # fill holes in the brain mask, without changing FOV
# fileOut="${EPIpath}/rT1_brain_mask_FC.nii.gz"
# cmd="fslmaths ${fileOut} -fillh ${fileOut}"
# log $cmd
# eval $cmd 

# fileOut2="${EPIpath}/6_epi.nii.gz"
# cmd="fslmaths ${fileOut2} -mas ${fileOut} ${fileOut2}"
# log $cmd
# eval $cmd 





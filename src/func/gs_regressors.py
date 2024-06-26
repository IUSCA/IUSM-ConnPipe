
import os
import sys
import numpy as np
import nibabel as nib
from scipy.io import savemat

def get_ts(vol,numTP,rest):
    numVoxels = np.count_nonzero(vol)
    print("numVoxels - ",numVoxels)
    mask = np.nonzero(vol != 0)
    ts = np.zeros((numVoxels,numTP))
    for ind in range(0,numTP):
        rvol = rest[:,:,:,ind]
        rvals = rvol[mask[0],mask[1],mask[2]]
        ts[:,ind] = rvals
    return ts,mask


print("\n *** python global signal calculation **** ")
EPIpath=os.environ['EPIrun_out']
fileIN=sys.argv[1]
print("fileIN ", fileIN)
NuisancePhysReg_out=sys.argv[2]
print("NuisancePhysReg_out ", NuisancePhysReg_out)
compute_gs=int(sys.argv[3])
print("compute_gs ", compute_gs)


### load data and masks
resting = nib.load(fileIN)
resting_vol = np.asanyarray(resting.dataobj)
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
print("resting_vol.shape ", sizeX,sizeY,sizeZ,numTimePoints)

### Global Signal time-series
if 0 < compute_gs < 5:
    fname = ''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
    volGS = nib.load(fname)
    volGS_vol = np.asanyarray(volGS.dataobj)
    [GSts,GSmask] = get_ts(volGS_vol,numTimePoints,resting_vol)
    GSavg = np.mean(GSts,axis=0)
    GSderiv = np.append(0,np.diff(GSavg))
    GSavg_sq = np.power(GSavg,2)
    GSderiv_sq = np.power(GSderiv,2)

    # save the data
    fname = ''.join([NuisancePhysReg_out,'/dataGS.npz'])
    np.savez(fname,GSavg=GSavg,GSavg_sq=GSavg_sq,GSderiv=GSderiv,GSderiv_sq=GSderiv_sq)
    fname = ''.join([NuisancePhysReg_out,'/dataGS.mat'])
    print("savign MATLAB file ", fname)
    mdic = {"GSavg" : GSavg,"GSavg_sq" : GSavg_sq, "GSderiv" : GSderiv,"GSderiv_sq" : GSderiv_sq}
    savemat(fname, mdic)
    print("saved global signal regressors")    


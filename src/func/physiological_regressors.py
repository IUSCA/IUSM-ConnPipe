
import os
import sys
import numpy as np
import nibabel as nib
from scipy.io import savemat

print("\n *** python physiological regressors **** ")
EPIpath=os.environ['EPIrun_out']
fileIN=sys.argv[1]
print("fileIN "+ fileIN)
physReg=sys.argv[2]
print("physReg "+ physReg)
num_comp=int(sys.argv[3])
print("um_comp ", num_comp)
NuisancePhysReg_out=sys.argv[4]
print("NuisancePhysReg_out "+ NuisancePhysReg_out)


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

def get_pca(data, n_comp):
    
    from sklearn.decomposition import PCA

    print("data shape: ",data.shape)

    pca = PCA(n_components = n_comp)  
    pca.fit(data)
    PC = pca.components_
    print("PC shape ",PC.shape)
    PCtop = PC
    latent = pca.explained_variance_
    print("latent: ",latent) 
    variance = np.true_divide(np.cumsum(latent),np.sum(latent))
    print("explained variance: ",variance) 
    
    return PCtop,variance  


### load data and masks
resting = nib.load(fileIN)
resting_vol = np.asanyarray(resting.dataobj)
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
print("resting_vol.shape ", sizeX,sizeY,sizeZ,numTimePoints)

fname = ''.join([EPIpath,'/rT1_CSFvent_mask_eroded.nii.gz'])
volCSFvent_vol = np.asanyarray(nib.load(fname).dataobj)
numVoxels = np.count_nonzero(volCSFvent_vol)

fname = ''.join([EPIpath,'/rT1_WM_mask_eroded.nii.gz'])
volWM_vol = np.asanyarray(nib.load(fname).dataobj)
numVoxels = np.count_nonzero(volWM_vol)

### CSFvent time-series
[CSFts,CSFmask] = get_ts(volCSFvent_vol,numTimePoints,resting_vol)

### WM time-series
[WMts,WMmask] = get_ts(volWM_vol,numTimePoints,resting_vol)


if physReg == 'aCompCor':
    print("-------------aCompCorr--------------")    
    [CSFpca,CSFvar] = get_pca(CSFts,num_comp)
    print("\n Running PCA on CSF time-series.\n")

    [WMpca,WMvar] = get_pca(WMts,num_comp)
    print("\n Running PCA on WM time-series.\n")
    
    # save the data
    fname = ''.join([NuisancePhysReg_out,'/dataPCA',str(num_comp),'_WM-CSF.npz'])
    np.savez(fname,CSFpca=CSFpca,CSFvar=CSFvar,CSFmask=CSFmask,CSFts=CSFts,WMpca=WMpca,WMvar=WMvar,WMmask=WMmask,WMts=WMts)
    fname = ''.join([NuisancePhysReg_out,'/dataPCA',str(num_comp),'_WM-CSF.mat'])
    print("saving MATLAB file ", fname)
    mdic = {"CSFpca" : CSFpca,"CSFvar" : CSFvar,"CSFmask" : CSFmask,"CSFts" : CSFts,"WMpca" : WMpca,"WMvar" : WMvar,"WMmask" : WMmask,"WMts" : WMts}
    savemat(fname, mdic)
    print("Saved aCompCor PCA regressors")

elif physReg == 'meanPhysReg':
    print("-------------Mean CSF and WM Regression--------------")
    CSFavg = np.mean(CSFts,axis=0)
    CSFderiv = np.append(0,np.diff(CSFavg))
    CSFavg_sq = np.power(CSFavg,2)
    CSFderiv_sq = np.power(CSFderiv,2)

    WMavg = np.mean(WMts,axis=0)
    WMderiv = np.append(0,np.diff(WMavg))
    WMavg_sq = np.power(WMavg,2)
    WMderiv_sq = np.power(WMderiv,2)

    # save the data
    fname = ''.join([NuisancePhysReg_out,'/dataMnRg_WM-CSF.npz'])
    np.savez(fname,CSFavg=CSFavg,CSFavg_sq=CSFavg_sq,CSFderiv=CSFderiv,CSFderiv_sq=CSFderiv_sq,WMavg=WMavg,WMavg_sq=WMavg_sq,WMderiv=WMderiv,WMderiv_sq=WMderiv_sq)
    print("savign MATLAB file ", fname)
    fname = ''.join([NuisancePhysReg_out,'/dataMnRg_WM-CSF.mat'])
    mdic = {"CSFavg" : CSFavg,"CSFavg_sq" : CSFavg_sq,"CSFderiv" : CSFderiv,"CSFderiv_sq" : CSFderiv_sq,"WMavg" : WMavg,"WMavg_sq" : WMavg_sq,"WMderiv" : WMderiv,"WMderiv_sq" : WMderiv_sq}
    savemat(fname, mdic)
    print("saved mean CSF WM signal, derivatives, and quadtatics")  
else:
    print("ERROR physReg value not recognized!")



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

function read_data() {
EPIpath="$1" python - <<END
import os
import numpy as np
import nibabel as nib

EPIpath=os.environ['EPIpath']

# read brain mask
fname = ''.join([EPIpath,'/rT1_brain_mask.nii.gz'])
volBrain = nib.load(fname)
volBrain_vol = volBrain.get_data()

fname = ''.join([EPIpath,'/2_epi_meanvol_mask.nii.gz'])
volRef = nib.load(fname)
volRef_vol = volRef.get_data()

volBrain_vol = (volBrain_vol>0) & (volRef_vol != 0)
fileOut=''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
volBrain_new = nib.Nifti1Image(volBrain_vol.astype(np.float32),volBrain.affine,volBrain.header)
nib.save(volBrain_new,fileOut)  

END
}

function time_series() {
EPIpath="$1" fileIN="$2" aCompCorr="$3" \
    num_comp="$4" PhReg_path="$5" \
    numGS="$6" python - <<END

import os
import numpy as np
import nibabel as nib
from scipy.io import savemat


EPIpath=os.environ['EPIpath']
print("EPIpath",EPIpath)
fileIN=os.environ['fileIN']
print("fileIN",fileIN)
aCompCorr=os.environ['aCompCorr']
print("aCompCorr",aCompCorr)
num_comp=int(os.environ['num_comp'])
print("num_comp",num_comp)
PhReg_path=os.environ['PhReg_path']
print("PhReg_path",PhReg_path)
numGS=int(os.environ['numGS'])
print("numGS",numGS)

QCfile_name=os.environ['QCfile_name']
QCfile_name = ''.join([QCfile_name,'.log'])
print("QCfile_name: ",QCfile_name)
f=open(QCfile_name, "a+")

def get_ts(vol,numTP,rest):
    numVoxels = np.count_nonzero(vol);
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

    pca = PCA()  #(n_components = n_comp) 
    pca.fit(data)
    PC = pca.components_
    print("PC shape ",PC.shape)
    PCtop = PC[:,0:n_comp]
    latent = pca.explained_variance_
    print("latent: ",latent[0:n_comp])
    variance = np.true_divide(np.cumsum(latent),np.sum(latent))
    print("explained variance: ",variance[0:n_comp])
    
    # return PCtop,latent[0:n_comp],variance[0:n_comp]
    return PCtop,variance[0:n_comp]


### load data and masks
resting = nib.load(fileIN)
resting_vol = resting.get_data()
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
print("resting_vol.shape ", sizeX,sizeY,sizeZ,numTimePoints)

fname = ''.join([EPIpath,'/rT1_CSFvent_mask_eroded.nii.gz'])
volCSFvent_vol = nib.load(fname).get_data()
numVoxels = np.count_nonzero(volCSFvent_vol);
if numVoxels < numTimePoints:
    fname = ''.join([EPIpath,'/rT1_CSFvent_mask.nii.gz'])
    volCSFvent_vol = nib.load(fname).get_data()
    numVoxels = np.count_nonzero(volCSFvent_vol);
    if numVoxels < numTimePoints:
        print("WARNING: number of voxels in non-eroded CSFvent mask is smaller than number of Time points; PCA will fail")
        f.write("\n WARNING: number of voxels in non-eroded CSFvent mask is smaller than number of Time points; PCA will fail \n")
        flag_PCA_CSF=False
    else:
        print("WARNING: using non-eroded CSFvent mask in PhysiolReg")
        f.write("\n WARNING: using non-eroded CSFvent mask in PhysiolReg \n")
        flag_PCA_CSF=True
else:
    print("Using eroded CSFvent mask in PhysiolReg")
    f.write("\n ==> Using eroded CSFvent mask in PhysiolReg \n")
    flag_PCA_CSF=True



fname = ''.join([EPIpath,'/rT1_WM_mask_eroded.nii.gz'])
volWM_vol = nib.load(fname).get_data()
numVoxels = np.count_nonzero(volWM_vol);
if numVoxels < numTimePoints:
    fname = ''.join([EPIpath,'/rT1_WM_mask_eroded_2nd.nii.gz'])
    volWM_vol = nib.load(fname).get_data()
    numVoxels = np.count_nonzero(volWM_vol);
    if numVoxels < numTimePoints:
        fname = ''.join([EPIpath,'/rT1_WM_mask_eroded_1st.nii.gz'])
        volWM_vol = nib.load(fname).get_data()
        numVoxels = np.count_nonzero(volWM_vol);
        if numVoxels < numTimePoints:
            print("WARNING: number of voxels in 1st eroded WM mask is smaller than number of Time points; PCA will fail")
            f.write("\n WARNING: number of voxels in 1st-eroded WM mask is smaller than number of Time points; PCA will fail \n")
            flag_PCA_WM=False
        else:
            print("WARNING: using 1st-eroded WM mask")
            f.write("\n WARNING: using 1st-eroded WM mask in PhysiolReg \n")
            flag_PCA_WM=True
    else:
        print("WARNING: using 2nd-eroded WM mask")
        f.write("\n WARNING: using 2nd-eroded WM mask in PhysiolReg \n")
        flag_PCA_WM=True
else:
    print("Using 3rd eroded WM mask in PhysiolReg")
    f.write("\n ==> Using 3rd eroded WM mask in PhysiolReg \n")
    flag_PCA_WM=True

f.close()

fname = ''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
volGS = nib.load(fname)
volGS_vol = volGS.get_data()

### CSFvent time-series
[CSFts,CSFmask] = get_ts(volCSFvent_vol,numTimePoints,resting_vol);

### WM time-series
[WMts,WMmask] = get_ts(volWM_vol,numTimePoints,resting_vol);

### Global Signal time-series
[GSts,GSmask] = get_ts(volGS_vol,numTimePoints,resting_vol);
# # save mask for later
# fname = ''.join([PhReg_path,'/GSmask.npz'])
# np.savez(fname,GSmask=GSmask)

if flag_PCA_CSF is False and flag_PCA_WM is False and aCompCorr.lower() in ['true','1']:
    aCompCorr='false'
    f.write("\n WARNING: PCA will fail for both CSF and WM.\n")
    f.write("\n Using Head Motion Parameters for regression, instead of aCompCorr \n")


if aCompCorr.lower() in ['true','1']:
    print("-------------aCompCorr--------------")
    f.write("\n -------------aCompCorr--------------.\n")
    
    if flag_PCA_CSF:
        [CSFpca,CSFvar] = get_pca(CSFts.T,num_comp)
        f.write("\n Running PCA on CSF time-series.\n")
    else:
        CSFpca = np.mean(CSFts,axis=0)
        CSFvar = 0
        f.write("\n WARNING Cannot Perform PCA on CSF time-series. Using mean signal instead.\n")

    if flag_PCA_WM:
        [WMpca,WMvar] = get_pca(WMts.T,num_comp)
        f.write("\n Running PCA on WM time-series.\n")
    else:
        WMpca = np.mean(WMts,axis=0)
        WMvar = 0
        f.write("\n WARNING Cannot Perform PCA on WM time-series. Using mean signal instead.\n")

    # save the data
    fname = ''.join([PhReg_path,'/dataPCA_WM-CSF.npz'])
    np.savez(fname,CSFpca=CSFpca,CSFvar=CSFvar,CSFmask=CSFmask,CSFts=CSFts,WMpca=WMpca,WMvar=WMvar,WMmask=WMmask,WMts=WMts)
    fname = ''.join([PhReg_path,'/dataPCA_WM-CSF.mat'])
    print("savign MATLAB file ", fname)
    mdic = {"CSFpca" : CSFpca,"CSFvar" : CSFvar,"CSFmask" : CSFmask,"CSFts" : CSFts,"WMpca" : WMpca,"WMvar" : WMvar,"WMmask" : WMmask,"WMts" : WMts}
    savemat(fname, mdic)
    print("Saved aCompCor PCA regressors")

else:
    print("-------------Mean CSF and WM Regression--------------")
    f.write("\n ------------Mean CSF and WM Regression--------------.\n")
    CSFavg = np.mean(CSFts,axis=0)
    CSFderiv = np.append(0,np.diff(CSFavg));
    CSFavg_sq = np.power(CSFavg,2)
    CSFderiv_sq = np.power(CSFderiv,2)

    WMavg = np.mean(WMts,axis=0)
    WMderiv = np.append(0,np.diff(WMavg));
    WMavg_sq = np.power(WMavg,2)
    WMderiv_sq = np.power(WMderiv,2)

    # save the data
    fname = ''.join([PhReg_path,'/dataMnRg_WM-CSF.npz'])
    np.savez(fname,CSFavg=CSFavg,CSFavg_sq=CSFavg_sq,CSFderiv=CSFderiv,CSFderiv_sq=CSFderiv_sq,WMavg=WMavg,WMavg_sq=WMavg_sq,WMderiv=WMderiv,WMderiv_sq=WMderiv_sq)
    print("savign MATLAB file ", fname)
    fname = ''.join([PhReg_path,'/dataMnRg_WM-CSF.mat'])
    mdic = {"CSFavg" : CSFavg,"CSFavg_sq" : CSFavg_sq,"CSFderiv" : CSFderiv,"CSFderiv_sq" : CSFderiv_sq,"WMavg" : WMavg,"WMavg_sq" : WMavg_sq,"WMderiv" : WMderiv,"WMderiv_sq" : WMderiv_sq}
    savemat(fname, mdic)
    print("saved mean CSF WM signal, derivatives, and quadtatics")  
      

if 0 < numGS < 5:
    GSavg = np.mean(GSts,axis=0)
    GSderiv = np.append(0,np.diff(GSavg));
    # transpose vectors
    # GSavg = GSavg[:,np.newaxis];
    # GSderiv = GSderiv[:,np.newaxis];
    GSavg_sq = np.power(GSavg,2)
    GSderiv_sq = np.power(GSderiv,2)

    # save the data
    fname = ''.join([PhReg_path,'/dataGS.npz'])
    np.savez(fname,GSavg=GSavg,GSavg_sq=GSavg_sq,GSderiv=GSderiv,GSderiv_sq=GSderiv_sq)
    print("savign MATLAB file ", fname)
    fname = ''.join([PhReg_path,'/dataGS.mat'])
    mdic = {"GSavg" : GSavg,"GSavg_sq" : GSavg_sq, "GSderiv" : GSderiv,"GSderiv_sq" : GSderiv_sq}
    savemat(fname, mdic)
    print("saved global signal regressors")      

END
}

##############################################################################

## PHYSIOLOGICAL REGRESSORS
echo "# =========================================================="
echo "# 5.2 PHYSIOLOGICAL REGRESSORS "
echo "# =========================================================="

if ${flags_PhysiolReg_aCompCorr}; then  
    log "- -----------------aCompCor---------------------"      
elif ${flags_PhysiolReg_WM_CSF}; then
    log "- -----------------Mean CSF and WM Regression-----------------"
fi 

if ${flags_NuisanceReg_AROMA}; then   

    fileIN="${EPIpath}/AROMA/AROMA-output/denoised_func_data_nonaggr.nii.gz"
    if  [[ -e ${fileIN} ]]; then
        if ${flags_PhysiolReg_aCompCorr}; then  
            log "PhysiolReg - Combining aCompCorr with AROMA output data"
        elif ${flags_PhysiolReg_WM_CSF}; then
            log "PhysiolReg - Combining Mean CSF & WM signal with AROMA output data"
            configs_EPI_numPC=0
        fi          
    else
        log "ERROR ${fileIN} not found. Connot perform physiological regressors analysis"
    fi 

elif ${flags_NuisanceReg_HeadParam}; then 

    fileIN="${EPIpath}/4_epi.nii.gz"
    if  [[ -e ${fileIN} ]] && [[ -d "${EPIpath}/HMPreg" ]]; then
        if ${flags_PhysiolReg_aCompCorr}; then  
            log "PhysiolReg - Combining aCompCorr with HMP regressors"
        elif ${flags_PhysiolReg_WM_CSF}; then
            log "PhysiolReg - Combining Mean CSF & WM signal with HMP regressors"
            configs_EPI_numPC=0
        fi          
    else
        log "ERROR ${fileIN} and or ${EPIpath}/HMPreg not found. Connot perform physiological regressors analysis"
    fi 
fi

PhReg_path="${EPIpath}/${regPath}"

if [[ ! -d ${PhReg_path} ]]; then
    cmd="mkdir ${PhReg_path}"
    log $cmd
    eval $cmd 
fi

# read in data and masks 
read_data ${EPIpath}

# fill holes in the brain mask, without changing FOV
fileOut="${EPIpath}/rT1_brain_mask_FC.nii.gz"
cmd="fslmaths ${fileOut} -fillh ${fileOut}"
log $cmd
eval $cmd

if ${flags_EPI_GS}; then
    log "============== GLOBAL SIGNAL REGRESSION =================="
else
    configs_EPI_numGS=0
fi

time_series ${EPIpath} \
    ${fileIN} ${flags_PhysiolReg_aCompCorr} \
    ${configs_EPI_numPC} ${PhReg_path} ${configs_EPI_numGS}



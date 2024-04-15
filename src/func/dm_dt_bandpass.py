
import os
import sys
import nibabel as nib
import numpy as np
from scipy import stats
from scipy import signal
from scipy.io import savemat


EPIpath=os.environ['EPIrun_out']
print("EPIpath ",EPIpath)
dvars_despike=os.environ['configs_EPI_despike']
print("\n dvars_despike ", dvars_despike)
fileIn=sys.argv[1]
print("fileIn ",fileIn)
fileOut=sys.argv[2]
print("fileOut ",fileOut)
NuisancePhysReg_out=os.environ['NuisancePhysReg_out']
print("NuisancePhysReg_out ",NuisancePhysReg_out)
TR=float(os.environ['TR'])
print("TR ",str(TR))
nR=os.environ['nR']
print("nR ",nR)

# load resting vol image to use header for saving new image.    
resting_file=os.environ['configs_EPI_resting_file']
print("resting_file ",resting_file)
resting_file = ''.join([EPIpath,resting_file])   
resting = nib.load(resting_file)
resting_vol = np.asanyarray(resting.dataobj)
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
print("resting_vol.shape ", sizeX,sizeY,sizeZ,numTimePoints)

print("loading resid for Demean and Detrend")
data = np.load(fileIn)

if dvars_despike == 'true':
    resid_array = ["resid", "resid_despike"]
else:
    resid_array = ["resid"]

fname = ''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
volBrain_vol = np.asanyarray(nib.load(fname).dataobj)

# bandpass prep
fmin=float(os.environ['configs_EPI_fMin'])
print("fmin ",fmin)
fmax=float(os.environ['configs_EPI_fMax'])
print("fmax ",fmax)

order = 2  
f1 = fmin*2*TR
f2 = fmax*2*TR
print("order is ",order)
print("f1 is ",f1)
print("f2 is ",f2)

# create mask-array with non-zero indices
GSmask = np.nonzero(volBrain_vol != 0)

numVoxels = np.count_nonzero(volBrain_vol)
print("numVoxels - ",numVoxels)


print("Resuduals array elements: ",len(resid_array))

for ra in resid_array:
    print("---- iterating over "+ra)

    resid = data[ra]

    # demean and detrend
    for i in range(0,sizeX):
        for j in range(0,sizeY):
            for k in range(0,sizeZ):
                if volBrain_vol[i,j,k] > 0:
                    TSvoxel = resid[i,j,k,:].reshape(numTimePoints,1)
                    #TSvoxel_detrended = signal.detrend(TSvoxel-np.mean(TSvoxel),type='linear')
                    TSvoxel_detrended = signal.detrend(TSvoxel-np.mean(TSvoxel),axis=0,type='linear')
                    resid[i,j,k,:] = TSvoxel_detrended.reshape(1,1,1,numTimePoints)

        if i % 25 == 0:
            print(i/sizeX)  ## change this to percentage progress 

    # zero-out voxels that are outside the GS mask
    for t in range(0,numTimePoints):
        rv = resid[:,:,:,t]
        rv[volBrain_vol==0]=0
        resid[:,:,:,i] = rv

    # Bandpass filetring
    GSts_resid = np.zeros((numTimePoints,numVoxels))
    print("GSts_resid shape is ",GSts_resid.shape)

    for ind in range(0,numTimePoints):
        rrvol = resid[:,:,:,ind]
        rvals = rrvol[GSmask[0],GSmask[1],GSmask[2]]
        GSts_resid[ind,:] = rvals

    b, a = signal.butter(order, [fmin, fmax], btype='bandpass', analog=False)

    GSts_resid=GSts_resid.T

    tsf = signal.filtfilt(b, a, GSts_resid, padtype='even', padlen=100)  # 3 * (max(len(b), len(a))-1)

    tsf=tsf.T

    for ind in range(0,numTimePoints):
        resid[GSmask[0],GSmask[1],GSmask[2],ind] = tsf[ind,:]

    if dvars_despike == 'true' and ra == "resid_despike":
        fileNii = "/6_epi_%s_despiked.nii.gz" % nR 
        print("Saving despiked demeaned and detrended data as "+fileNii)
        resid_despike = resid
    else:
        fileNii = "/6_epi_%s.nii.gz" % nR 
        print("Saving demeaned and detrended data as "+fileNii)
        resid_nd = resid
        

    fileNii = ''.join([NuisancePhysReg_out,fileNii])
    print("Nifti file to be saved is: ",fileNii)

    # save new resting file
    resting_new = nib.Nifti1Image(resid.astype(np.float32),resting.affine,resting.header)
    nib.save(resting_new,fileNii) 


## save data 
ff = ''.join([fileOut,'.npz'])
# save DVARS in case user wants to scrub bandpassed data
DVARS_Inference_Hprac=data['DVARS_Inference_Hprac']
if dvars_despike == 'true':
    np.savez(ff,resid=resid_nd,resid_despike=resid_despike, \
        DVARS_Inference_Hprac=DVARS_Inference_Hprac)
else:
    np.savez(ff,resid=resid_nd, \
        DVARS_Inference_Hprac=DVARS_Inference_Hprac)


print("Saved bandpass filtered residuals")

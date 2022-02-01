
import os
import sys
import nibabel as nib
import numpy as np
from scipy import signal
from scipy.io import savemat


logfile_name = ''.join([os.environ['logfile_name'],'.log'])
flog=open(logfile_name, "a+")
flog.write("\n *** python apply_bandpass **** ")


EPIpath=os.environ['EPIpath']
print("EPIpath ",EPIpath)
fileIn=sys.argv[1]
print("fileIn ",fileIn)
fileOut=sys.argv[2]
print("fileOut ",fileOut)
regPath=os.environ['regPath']
print("regPath ",regPath)
dvars_scrub=os.environ['flags_EPI_DVARS']
print("dvars_scrub ", dvars_scrub)
nR=os.environ['nR']
print("nR ",nR)
resting_file=os.environ['configs_EPI_resting_file']
print("resting_file ",resting_file)

postfix = ''.join([nR,'_dmdt'])

data = np.load(fileIn)
resid=data['resid']
print("loading resid_DVARS for Demean and Detrend")

volBrain_vol=data['volBrain_vol']

resting_vol=data['resting_vol']
print("resting_vol.shape: ",resting_vol.shape)
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape


# load resting vol image to use header for saving new image.    
resting_file = ''.join([EPIpath,resting_file])   
resting = nib.load(resting_file)

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

    if len(resid)==1:
        fileNii = "/8_epi_%s.nii.gz" % postfix 
    else:
        fileNii = "/8_epi_%s%d.nii.gz" % (postfix,pc)

    fileNii = ''.join([EPIpath,'/',regPath,fileNii])
    print("Nifti file to be saved is: ",fileNii)

    # save new resting file
    resting_new = nib.Nifti1Image(resid[pc].astype(np.float32),resting.affine,resting.header)
    nib.save(resting_new,fileNii) 


## save data 
ff = ''.join([fileOut,'.npz'])
np.savez(ff,resid=resid)
print("Saved demeaned and detrended residuals")

ff = ''.join([fileOut,'.mat'])
print("savign MATLAB file ", ff)
mdic = {"resid" : resid}
savemat(ff, mdic)


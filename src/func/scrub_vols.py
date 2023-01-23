
import os
import sys
import numpy as np
import nibabel as nib
from scipy.io import savemat

logfile_name = ''.join([os.environ['logfile_name'],'.log'])
flog=open(logfile_name, "a+")

EPIpath=os.environ['EPIpath']
print("EPIpath ",EPIpath)
PhReg_path=sys.argv[1]
print("PhReg_path ",PhReg_path)
post_nR=sys.argv[2]
print("post_nR ",post_nR)
nR=os.environ['nR']
print("nR ",nR)
resting_file=os.environ['configs_EPI_resting_file']
print("resting_file ",resting_file)
dvars_scrub=os.environ['flags_EPI_DVARS']
flog.write("\n dvars_scrub "+ dvars_scrub)

# load resting vol image to use header for saving new image.    
resting_file = ''.join([EPIpath,resting_file])   
resting = nib.load(resting_file)

fname = ''.join([PhReg_path,'/NuisanceRegression_',post_nR,'.npz'])
data = np.load(fname) 
resid=data['resid']

[sizeX,sizeY,sizeZ,numTimePoints] = resid[0].shape
print("resid[0].shape ", sizeX,sizeY,sizeZ,numTimePoints)

# load DVARS / FD
if dvars_scrub == 'true': 
    fname = ''.join([PhReg_path,'/NuisanceRegression_',nR,'.npz'])
    scrubdata = np.load(fname) 
    dvars=scrubdata['DVARS_Inference_Hprac']
    print("DVARS: ",dvars)
    goodvols = np.ones(numTimePoints, dtype=int)
    goodvols[dvars]=0
else:
    fname=''.join([EPIpath,'/scrubbing_goodvols.npz'])  
    goodvols = np.load(fname) 
    goodvols = goodvols['good_vols'] 

# remove "bad vols"
print("Volumes to remove ",np.count_nonzero(goodvols==0))
print("shape resid before scrubbing ", resid.shape)
resid = resid[:,:,:,:,goodvols==1]
print("shape resid after scrubbing ", resid.shape)

for pc in range(0,len(resid)):

    if len(resid)==1:
        fileNii = "/8_epi_%s_scrubbed.nii.gz" % post_nR 
    else:
        fileNii = "/8_epi_%s%d_scrubbed.nii.gz" % (post_nR,pc)

    fileNii = ''.join([PhReg_path,fileNii])
    print("Nifti file to be saved is: ",fileNii)

    # save new resting file
    resting_new = nib.Nifti1Image(resid[pc].astype(np.float32),resting.affine,resting.header)
    nib.save(resting_new,fileNii) 

## save data 
fileOut = ''.join([PhReg_path,'/NuisanceRegression_',post_nR,'_scrubbed.npz'])
np.savez(fileOut,resid=resid)
print("Saved Scrubbed residuals")

# fileOut = ''.join([PhReg_path,'/NuisanceRegression_',post_nR,'_scrubbed.mat'])
# print("savign MATLAB file ", fileOut)
# mdic = {"resid" : resid[0]}
# savemat(fileOut, mdic)

flog.close()


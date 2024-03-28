
import os
import sys
import numpy as np
import nibabel as nib
from scipy.io import savemat

###### print to log files #######
logfile_name = ''.join([os.environ['logfile_name'],'.log'])
flog=open(logfile_name, "a+")

EPIpath=os.environ['EPIrun_out']
print("EPIpath ",EPIpath)
NuisancePhysReg_out=os.environ['NuisancePhysReg_out']
print("NuisancePhysReg_out ",NuisancePhysReg_out)

nR=os.environ['nR']
print("nR ",nR)

configs_scrub=os.environ['configs_scrub']
flog.write("\n configs_scrub "+ configs_scrub)

# load resting vol image to use header for saving new image. 
resting_file=os.environ['configs_EPI_resting_file']
resting_file = ''.join([EPIpath,resting_file])    
flog.write("\n resting_file "+ resting_file)
resting = nib.load(resting_file)

fileIn=sys.argv[1]
print("fileIn ",fileIn)
fileOut=sys.argv[2]
print("fileOut ",fileOut)

# fname = ''.join([NuisancePhysReg_out,'/NuisanceRegression_',nR,'.npz'])
data = np.load(fileIn) 
resid=data['resid']   # load non-despiked residuals

[sizeX,sizeY,sizeZ,numTimePoints] = resid.shape
print("resid.shape ", sizeX,sizeY,sizeZ,numTimePoints)

# load DVARS / FD
# if 'DVARS_Inference_Hprac' in data:
if configs_scrub == "stat_DVARS":
    flog.write("\n *** Scrubbing with Statisitical DVARS **** \n\n")
    dvars=data['DVARS_Inference_Hprac']
    print("DVARS: ",dvars)
    goodvols = np.ones(numTimePoints, dtype=int)
    goodvols[dvars]=0
elif configs_scrub == "fsl_fd_dvars":
    flog.write("\n *** Scrubbing with FSL's dvars and fd *** \n\n")
    fname=''.join([EPIpath,'/scrubbing_goodvols.npz'])  
    goodvols = np.load(fname) 
    goodvols = goodvols['good_vols'] 

# remove "bad vols"
print("Volumes to remove ",np.count_nonzero(goodvols==0))
print("shape resid before scrubbing ", resid.shape)
resid = resid[:,:,:,goodvols==1]
print("shape resid after scrubbing ", resid.shape)

# for pc in range(0,len(resid)):

    # if len(resid)==1:
fileNii = "/8_epi_%s_scrubbed.nii.gz" % nR 
    # else:
    #     fileNii = "/8_epi_%s%d_scrubbed.nii.gz" % (nR,pc)

fileNii = ''.join([NuisancePhysReg_out,fileNii])
print("Nifti file to be saved is: ",fileNii)

# save new resting file
resting_new = nib.Nifti1Image(resid.astype(np.float32),resting.affine,resting.header)
nib.save(resting_new,fileNii) 

## save data 
# fileOut = ''.join([NuisancePhysReg_out,'/NuisanceRegression_',nR,'_scrubbed.npz'])
ff = ''.join([fileOut,'.npz'])
np.savez(ff,resid=resid)
print("Saved Scrubbed residuals")

ff = ''.join([fileOut,'.mat'])
print("savign MATLAB file ", ff)
mdic = {"resid" : resid}
savemat(ff, mdic)

flog.close()
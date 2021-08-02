
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

function apply_bandpass() {
PhReg_path="$1" TR="$2" fileOut="$3" python - <<END
import os
import numpy as np
import nibabel as nib
from scipy import signal
from scipy.io import savemat

logfile_name = ''.join([os.environ['logfile_name'],'.log'])
flog=open(logfile_name, "a+")

EPIpath=os.environ['EPIpath']
print("EPIpath ",EPIpath)
PhReg_path=os.environ['PhReg_path']
print("PhReg_path ",PhReg_path)
nR=os.environ['nR']
print("nR ",nR)
fileOut=os.environ['fileOut']
print("fileOut ",fileOut)
flags_EPI_DemeanDetrend=os.environ['flags_EPI_DemeanDetrend']
print("flags_EPI_DemeanDetrend ", flags_EPI_DemeanDetrend)
resting_file=os.environ['configs_EPI_resting_file']
print("resting_file ",resting_file)

# load resting vol image to use header for saving new image.    
resting_file = ''.join([EPIpath,resting_file])   
resting = nib.load(resting_file)

fname = ''.join([PhReg_path,'/NuisanceRegression_',nR,'.npz'])
data = np.load(fname) 

if flags_EPI_DemeanDetrend.lower() in ['true','1']:
    flog.write("\n Loading demeaned and detrended residuals")
    fname_dmdt = ''.join([PhReg_path,'/NuisanceRegression_',nR,'_dmdt.npz'])
    print("loading ",fname_dmdt)
    data_dmdt = np.load(fname_dmdt) 
    resid = data_dmdt['resid'] # Deman and Detrend has already handeled DVARS
    postfix = ''.join([nR,'_dmdt_Butter'])
else:
    flog.write("\n Loading residuals - skipping post-regression demean and detrend")
    resid=data['resid']
    print("loading residuals for Bandpass")
    postfix = ''.join([nR,'_Butter'])

[sizeX,sizeY,sizeZ,numTimePoints] = resid[0].shape
print("resid[0].shape ", sizeX,sizeY,sizeZ,numTimePoints)

volBrain_vol = data['volBrain_vol']
print("volBrain_vol shape ",volBrain_vol.shape)

TR= float(os.environ['TR'])
print("TR ",TR)
fmin= float(os.environ['configs_EPI_fMin'])
print("fmin ",fmin)
fmax= float(os.environ['configs_EPI_fMax'])
print("fmax ",fmax)

order = 2  
f1 = fmin*2*TR
f2 = fmax*2*TR
print("order is ",order)
print("f1 is ",f1)
print("f2 is ",f2)

# create mask-array with non-zero indices
GSmask = np.nonzero(volBrain_vol != 0)

numVoxels = np.count_nonzero(volBrain_vol);
print("numVoxels - ",numVoxels)

for pc in range(0,len(resid)):

    rr = resid[pc]

    GSts_resid = np.zeros((numTimePoints,numVoxels))
    print("GSts_resid shape is ",GSts_resid.shape)
    
    for ind in range(0,numTimePoints):
        rrvol = rr[:,:,:,ind]
        rvals = rrvol[GSmask[0],GSmask[1],GSmask[2]]
        GSts_resid[ind,:] = rvals
    
    b, a = signal.butter(order, [fmin, fmax], btype='bandpass', analog=False)

    GSts_resid=GSts_resid.T

    tsf = signal.filtfilt(b, a, GSts_resid, padtype='even', padlen=100)  # 3 * (max(len(b), len(a))-1)

    tsf=tsf.T
    
    for ind in range(0,numTimePoints):
        rr[GSmask[0],GSmask[1],GSmask[2],ind] = tsf[ind,:]

    resid[pc] = rr

    if len(resid)==1:
        fileNii = "/8_epi_%s.nii.gz" % postfix 
    else:
        fileNii = "/8_epi_%s%d.nii.gz" % (postfix,pc)

    fileNii = ''.join([PhReg_path,fileNii])
    print("Nifti file to be saved is: ",fileNii)

    # save new resting file
    resting_new = nib.Nifti1Image(resid[pc].astype(np.float32),resting.affine,resting.header)
    nib.save(resting_new,fileNii) 

## save data 
ff = ''.join([fileOut,'.npz'])
np.savez(ff,resid=resid)
print("Saved Bandpassed residuals")

ff = ''.join([fileOut,'.mat'])
print("savign MATLAB file ", ff)
mdic = {"resid" : resid}
savemat(ff, mdic)

flog.close()


END
}


###################################################################################


log "# =========================================================="
log "# 7. Bandpass. "
log "# =========================================================="



PhReg_path="${EPIpath}/${regPath}"

# Make sure files exist
if ${flags_EPI_DemeanDetrend}; then 
    fileIn="${PhReg_path}/NuisanceRegression_${nR}_dmdt.npz"
    fileOut="${PhReg_path}/NuisanceRegression_${nR}_dmdt_butter"
else
    fileIn="${PhReg_path}/NuisanceRegression_${nR}.npz"
    fileOut="${PhReg_path}/NuisanceRegression_${nR}_butter"
fi

log "Using ${fileIn}"

if [[ ! -e "${fileIn}" ]]; then  
    log " WARNING ${fileIn} not found. Exiting..."
    exit 1    
fi 

log "Output file will be named ${fileOut}"

log "apply_bandpass ${PhReg_path} ${TR} ${fileOut}"
apply_bandpass ${PhReg_path} ${TR} ${fileOut}


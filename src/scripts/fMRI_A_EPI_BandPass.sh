
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
EPIpath="$1" PhReg_path="$2" TR="$3" python - <<END
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
postfix=os.environ['nR']
print("postfix ",postfix)
resting_file=os.environ['configs_EPI_resting_file']
print("resting_file ",resting_file)

# numDCT=int(os.environ['configs_EPI_numDCT'])
# print("numDCT ",numDCT)

flags_EPI_DemeanDetrend=os.environ['flags_EPI_DemeanDetrend']
print("lags_EPI_DemeanDetrend ", flags_EPI_DemeanDetrend)

# load resting vol image to use header for saving new image. 
resting_file = ''.join([EPIpath,resting_file])
resting = nib.load(resting_file)

fname = ''.join([PhReg_path,'/NuisanceRegression_',postfix,'_output.npz'])
data = np.load(fname) 

if flags_EPI_DemeanDetrend.lower() in ['true','1']:
    flog.write("\n Loading demeaned and detrended residuals")
    fname_dmdt = ''.join([PhReg_path,'/NuisanceRegression_',postfix,'_output_dmdt.npz'])
    data_dmdt = np.load(fname_dmdt) 
    resid = data_dmdt['resid']
else:
    flog.write("\n Loading residuals - skipping demean and detrend")
    resid = data['resid']

print("resid shape ",resid[0].shape)

volBrain_vol = data['volBrain_vol']
print("volBrain_vol shape ",volBrain_vol.shape)

# if 0 < numDCT:
#     print(numDCT," DCT regression performed. Skipping Butterworth filter ")

#     for pc in range(0,len(resid)):
        
#         resting_vol = resid[pc]

#         if len(resid)==1:
#             fileOut = "7_epi_%s.nii.gz" % postfix 
#         else:
#             fileOut = "7_epi_%s%d.nii.gz" % (postfix,pc)

#         fileOut = ''.join([PhReg_path,fileOut])
#         print("Nifti file to be saved is: ",fileOut)

#         # save new resting file
#         resting_new = nib.Nifti1Image(resting_vol.astype(np.float32),resting.affine,resting.header)
#         nib.save(resting_new,fileOut) 
# else:

TR= float(os.environ['TR'])
print("TR ",TR)
fmin= float(os.environ['configs_EPI_fMin'])
print("fmin ",fmin)
fmax= float(os.environ['configs_EPI_fMax'])
print("fmax ",fmax)

resting_vol=data['resting_vol']
print("resting_vol.shape: ",resting_vol.shape)
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
print("resting_vol.shape ", sizeX,sizeY,sizeZ,numTimePoints)

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
        resting_vol[GSmask[0],GSmask[1],GSmask[2],ind] = tsf[ind,:]

    if len(resid)==1:
        fileOut = "7_epi_%s_Butter.nii.gz" % postfix 
    else:
        fileOut = "7_epi_%s%d_Butter.nii.gz" % (postfix,pc)

    fileOut = ''.join([PhReg_path,fileOut])
    print("Nifti file to be saved is: ",fileOut)

    # save new resting file
    resting_new = nib.Nifti1Image(resting_vol.astype(np.float32),resting.affine,resting.header)
    nib.save(resting_new,fileOut) 

flog.close()


END
}


###################################################################################


log "# =========================================================="
log "# 7. Bandpass. "
log "# =========================================================="



PhReg_path="${EPIpath}/${regPath}/"
if ${flags_EPI_DemeanDetrend}; then 
    fileIn="${PhReg_path}/NuisanceRegression_${nR}_output_dmdt.npz"
else
    fileIn="${PhReg_path}/NuisanceRegression_${nR}_output.npz"
fi

log "Using ${fileIn}"

if [[ ! -e "${fileIn}" ]]; then  
    log " WARNING Residual timeseries from Nuisance Regressors not found. Exiting..."
    exit 1    
fi 


echo "apply_bandpass ${EPIpath} ${PhReg_path} ${nR} ${TR} ${configs_EPI_fMin} ${configs_EPI_fMax} ${configs_EPI_resting_file}"
apply_bandpass ${EPIpath} ${PhReg_path} ${TR}


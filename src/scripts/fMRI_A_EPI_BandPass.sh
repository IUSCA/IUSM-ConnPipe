
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
EPIpath="$1" PhReg_path="$2" postfix="$3" TR="$4" fmin="$5" fmax="$6" resting_file="$7" python - <<END
import os
import numpy as np
import nibabel as nib
from scipy import signal

EPIpath=os.environ['EPIpath']
print("EPIpath ",EPIpath)
PhReg_path=os.environ['PhReg_path']
print("PhReg_path ",PhReg_path)
postfix=os.environ['postfix']
print("postfix ",postfix)
TR= float(os.environ['TR'])
print("TR ",TR)
fmin= float(os.environ['fmin'])
print("fmin ",fmin)
fmax= float(os.environ['fmax'])
print("fmax ",fmax)
resting_file=os.environ['resting_file']
print("resting_file ",resting_file)

fname = ''.join([PhReg_path,'/NuisanceRegression_',postfix,'_output.npz'])
fname_dmdt = ''.join([PhReg_path,'/NuisanceRegression_',postfix,'_output_dmdt.npz'])
data = np.load(fname) 
data_dmdt = np.load(fname_dmdt) 

resid = data_dmdt['resid']
print("resid shape ",resid[0].shape)

volBrain_vol = data['volBrain_vol']
print("volBrain_vol shape ",volBrain_vol.shape)

# load resting vol
resting_file = ''.join([EPIpath,resting_file])
resting = nib.load(resting_file)
resting_vol = resting.get_data()
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
print("resting_vol.shape ", sizeX,sizeY,sizeZ,numTimePoints)

order = 1
f1 = fmin*2*TR
f2 = fmax*2*TR

# load GS mask
fname = ''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
volGS = nib.load(fname)
volGS_vol = volGS.get_data()
GSmask = np.nonzero(volGS_vol != 0)

numVoxels = np.count_nonzero(volBrain_vol);
print("numVoxels - ",numVoxels)

for pc in range(0,len(resid)):

    rr = resid[pc]
    GSts_resid = np.zeros((numTimePoints,numVoxels))
    
    for ind in range(0,numTimePoints):
        rrvol = rr[:,:,:,ind]
        rvals = rrvol[GSmask[0],GSmask[1],GSmask[2]]
        GSts_resid[ind,:] = rvals
    
    b, a = signal.butter(order, [fmin, fmax], btype='band')
    tsf = signal.filtfilt(b, a, GSts_resid)
    
    for ind in range(0,numTimePoints):
        # rrvol = resting_vol[:,:,:,ind]
        # rrvol[GSmask[0],GSmask[1],GSmask[2]] = tsf[ind,:]
        resting_vol[GSmask[0],GSmask[1],GSmask[2],ind] = tsf[ind,:]


if len(resid)==1:
    fileOut = "7_epi_%s.nii.gz" % postfix 
else:
    fileOut = "7_epi_%s%d.nii.gz" % (postfix,pc-1)

fileOut = ''.join([PhReg_path,fileOut])

# save new resting file
resting_new = nib.Nifti1Image(resting_vol.astype(np.float32),resting.affine,resting.header)
nib.save(resting_new,fileOut) 


END
}


###################################################################################


echo "# =========================================================="
echo "# 7. Bandpass. "
echo "# =========================================================="



PhReg_path="${EPIpath}/${regPath}"
fileIn="${PhReg_path}/NuisanceRegression_${nR}_output.npz"
fileIn_dmdt="${PhReg_path}/NuisanceRegression_${nR}_output_dmdt.npz"

if [[ ! -e "${fileIn_dmdt}" ]]; then  
    log " WARNING Residual timeseries from Nuisance Regressors not found. Exiting..."
    exit 1    
fi 


echo "apply_bandpass ${EPIpath} ${PhReg_path} ${nR} ${TR} ${configs_EPI_fMin} ${configs_EPI_fMax}"
apply_bandpass ${EPIpath} ${PhReg_path} ${nR} ${TR} ${configs_EPI_fMin} ${configs_EPI_fMax} ${configs_EPI_resting_file}


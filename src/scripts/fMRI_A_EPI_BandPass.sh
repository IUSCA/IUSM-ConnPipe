
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
from scipy.io import savemat


EPIpath=os.environ['EPIpath']
print("EPIpath ",EPIpath)
PhReg_path=os.environ['PhReg_path']
print("PhReg_path ",PhReg_path)
postfix=os.environ['postfix']
print("postfix ",postfix)
resting_file=os.environ['resting_file']
print("resting_file ",resting_file)
numDCT=int(os.environ['configs_EPI_numDCT'])
print("numDCT ",numDCT)

# load resting vol image to use header for saving new image. 
resting_file = ''.join([EPIpath,resting_file])
resting = nib.load(resting_file)

fname = ''.join([PhReg_path,'/NuisanceRegression_',postfix,'_output.npz'])
fname_dmdt = ''.join([PhReg_path,'/NuisanceRegression_',postfix,'_output_dmdt.npz'])
data = np.load(fname) 
data_dmdt = np.load(fname_dmdt) 

resid = data_dmdt['resid']
print("resid shape ",resid[0].shape)

volBrain_vol = data['volBrain_vol']
print("volBrain_vol shape ",volBrain_vol.shape)

if 0 < numDCT:

    print(numDCT," DCT regression performed. Skipping Butterworth filter ")

    for pc in range(0,len(resid)):
        
        resting_vol = resid[pc]

        if len(resid)==1:
            fileOut = "7_epi_%s.nii.gz" % postfix 
        else:
            fileOut = "7_epi_%s%d.nii.gz" % (postfix,pc)

        fileOut = ''.join([PhReg_path,fileOut])
        print("Nifti file to be saved is: ",fileOut)

        # save new resting file
        resting_new = nib.Nifti1Image(resting_vol.astype(np.float32),resting.affine,resting.header)
        nib.save(resting_new,fileOut) 

else:

    TR= float(os.environ['TR'])
    print("TR ",TR)
    fmin= float(os.environ['fmin'])
    print("fmin ",fmin)
    fmax= float(os.environ['fmax'])
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
        print(tsf)

        tsf=tsf.T
        
        for ind in range(0,numTimePoints):
            resting_vol[GSmask[0],GSmask[1],GSmask[2],ind] = tsf[ind,:]

        if len(resid)==1:
            fileOut = "7_epi_%s.nii.gz" % postfix 
        else:
            fileOut = "7_epi_%s%d.nii.gz" % (postfix,pc)

        fileOut = ''.join([PhReg_path,fileOut])
        print("Nifti file to be saved is: ",fileOut)

        # save new resting file
        resting_new = nib.Nifti1Image(resting_vol.astype(np.float32),resting.affine,resting.header)
        nib.save(resting_new,fileOut) 

        # fileOut = ''.join([PhReg_path,'7_epi_padtype_even_padlen_100_order2.mat'])
        # print("savign MATLAB file ", fileOut)
        # mdic = {"resting_vol" : resting_vol,"volBrain_vol" : volBrain_vol, "GSts_resid" : GSts_resid,"tsf" : tsf}
        # savemat(fileOut, mdic)

END
}


###################################################################################


log "# =========================================================="
log "# 7. Bandpass. "
log "# =========================================================="



PhReg_path="${EPIpath}/${regPath}/"
fileIn="${PhReg_path}/NuisanceRegression_${nR}_output.npz"
fileIn_dmdt="${PhReg_path}/NuisanceRegression_${nR}_output_dmdt.npz"

if [[ ! -e "${fileIn_dmdt}" ]]; then  
    log " WARNING Residual timeseries from Nuisance Regressors not found. Exiting..."
    exit 1    
fi 


echo "apply_bandpass ${EPIpath} ${PhReg_path} ${nR} ${TR} ${configs_EPI_fMin} ${configs_EPI_fMax} ${configs_EPI_resting_file}"
apply_bandpass ${EPIpath} ${PhReg_path} ${nR} ${TR} ${configs_EPI_fMin} ${configs_EPI_fMax} ${configs_EPI_resting_file}


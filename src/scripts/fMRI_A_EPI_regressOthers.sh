
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

function other_regressors() {
EPIpath="$1" fileIN="$2" PhReg_path="$3" python - <<END

import os
import numpy as np
import nibabel as nib
from scipy.io import savemat

###### print to log files #######
QCfile_name = ''.join([os.environ['QCfile_name'],'.log'])
fqc=open(QCfile_name, "a+")
logfile_name = ''.join([os.environ['logfile_name'],'.log'])
flog=open(logfile_name, "a+")


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


flog.write("\n *** python time_series **** ")
EPIpath=os.environ['EPIpath']
fileIN=os.environ['fileIN']
flog.write("\n"+"fileIN "+ fileIN)
PhReg_path=os.environ['PhReg_path']
flog.write("\n PhReg_path "+ PhReg_path)
configs_EPI_numGS=int(os.environ['configs_EPI_numGS'])
flog.write("\n configs_EPI_numGS "+ str(configs_EPI_numGS))
configs_EPI_dctfMin=float(os.environ['configs_EPI_dctfMin'])
flog.write("\n configs_EPI_dctfMin "+ str(configs_EPI_dctfMin))

### load data and masks
resting = nib.load(fileIN)
resting_vol = resting.get_data()
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
print("resting_vol.shape ", sizeX,sizeY,sizeZ,numTimePoints)

### Global Signal time-series
if 0 < configs_EPI_numGS < 5:
    fname = ''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
    volGS = nib.load(fname)
    volGS_vol = volGS.get_data()
    [GSts,GSmask] = get_ts(volGS_vol,numTimePoints,resting_vol);
    GSavg = np.mean(GSts,axis=0)
    GSderiv = np.append(0,np.diff(GSavg));
    GSavg_sq = np.power(GSavg,2)
    GSderiv_sq = np.power(GSderiv,2)

    # save the data
    fname = ''.join([PhReg_path,'/dataGS.npz'])
    np.savez(fname,GSavg=GSavg,GSavg_sq=GSavg_sq,GSderiv=GSderiv,GSderiv_sq=GSderiv_sq)
    fname = ''.join([PhReg_path,'/dataGS.mat'])
    print("savign MATLAB file ", fname)
    mdic = {"GSavg" : GSavg,"GSavg_sq" : GSavg_sq, "GSderiv" : GSderiv,"GSderiv_sq" : GSderiv_sq}
    savemat(fname, mdic)
    print("saved global signal regressors")    


if 0 < configs_EPI_dctfMin:

    TR= float(os.environ['TR'])
    print("TR ",TR)

    # compute K for kDCT bases to filter fMin Hertz -- k = fMin * 2 * TR * numTimePoints
    numDCT = int(np.ceil(configs_EPI_dctfMin * 2 * TR * numTimePoints))
    print("numDCT is ",numDCT)
    flog.write("\n numDCT "+ str(numDCT))
    actualFmin = numDCT/(2*TR*numTimePoints)
    print("actualFmin is ",actualFmin)
    flog.write("\n actualFmin "+ str(actualFmin)+"\n")

    dct = np.zeros((numTimePoints,numDCT))
    print("dct shape is ",dct.shape)
    idx = np.arange(0,numTimePoints)/(numTimePoints - 1)

    for n in range(0,numDCT):
        dct[:,n] = np.cos(idx * np.pi * (n+1))


    # save the data
    fname = ''.join([PhReg_path,'/dataDCT.npz'])
    np.savez(fname,dct=dct,numDCT=numDCT,actualFmin=actualFmin)
    fname = ''.join([PhReg_path,'/dataDCT.mat'])
    print("savign MATLAB file ", fname)
    mdic = {"dct" : dct, "numDCT":numDCT,"actualFmin":actualFmin}
    savemat(fname, mdic)
    print("saved DCT bases") 


fqc.close()
flog.close()


END
}

##############################################################################

## PHYSIOLOGICAL REGRESSORS
echo "# =========================================================="
echo "# 5.3 OTHER REGRESSORS "
echo "# =========================================================="


if ${flags_NuisanceReg_AROMA}; then   

    fileIN="${EPIpath}/AROMA/AROMA-output/denoised_func_data_nonaggr.nii.gz"
    if  [[ ! -e ${fileIN} ]]; then
        log "ERROR ${fileIN} not found. Connot perform regresso analysis"
        exit 1
    fi

elif ${flags_NuisanceReg_HeadParam}; then 

    fileIN="${EPIpath}/4_epi.nii.gz"
    if  [[ ! -e ${fileIN} ]] || [[ ! -d "${EPIpath}/HMPreg" ]]; then
        log "ERROR ${fileIN} and or ${EPIpath}/HMPreg not found. Connot perform physiological regressors analysis"
        exit 1
    fi 
fi

PhReg_path="${EPIpath}/${regPath}"

if [[ ! -d ${PhReg_path} ]]; then
    cmd="mkdir ${PhReg_path}"
    log $cmd
    eval $cmd 
fi


if ${flags_EPI_GS}; then
    log " Global signal regression is ON "
else
    log " Global signal regression is OFF "
    export configs_EPI_numGS=0
fi

if ${configs_EPI_DCThighpass}; then
    log " DCT bases will be included in regression "
else
    log " DCT bases will NOT be included in regression "
    export configs_EPI_dctfMin=0
fi

other_regressors ${EPIpath} ${fileIN} ${PhReg_path}



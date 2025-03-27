
import os
import sys
import numpy as np
import nibabel as nib
from scipy.io import savemat


print("\n *** python DCT regressors **** ")
# EPIpath=os.environ['EPIrun_out']
fileIN=sys.argv[1]
print("fileIN ", fileIN)
NuisancePhysReg_out=sys.argv[2]
print("\n NuisancePhysReg_out ", NuisancePhysReg_out)
configs_EPI_dctfMin=float(os.environ['configs_EPI_dctfMin'])
print("\n configs_EPI_dctfMin ", configs_EPI_dctfMin)

### load data and masks
resting = nib.load(fileIN)
resting_vol = np.asanyarray(resting.dataobj)
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
print("resting_vol.shape ", sizeX,sizeY,sizeZ,numTimePoints)


if 0 < configs_EPI_dctfMin:

    TR= float(os.environ['TR'])
    print("TR ",TR)

    # compute K for kDCT bases to filter fMin Hertz -- k = fMin * 2 * TR * numTimePoints
    numDCT = int(np.ceil(configs_EPI_dctfMin * 2 * TR * numTimePoints))
    print("numDCT is ",numDCT)
    print("\n numDCT ",numDCT)
    actualFmin = numDCT/(2*TR*numTimePoints)
    print("actualFmin is ",actualFmin)
    print("\n actualFmin ",actualFmin)

    dct = np.zeros((numTimePoints,numDCT))
    print("dct shape is ",dct.shape)
    idx = np.arange(0,numTimePoints)/(numTimePoints - 1)

    for n in range(0,numDCT):
        dct[:,n] = np.cos(idx * np.pi * (n+1))


    # save the data
    fname = ''.join([NuisancePhysReg_out,'/dataDCT.npz'])
    np.savez(fname,dct=dct,numDCT=numDCT,actualFmin=actualFmin)
    fname = ''.join([NuisancePhysReg_out,'/dataDCT.mat'])
    print("savign MATLAB file ", fname)
    mdic = {"dct" : dct, "numDCT":numDCT,"actualFmin":actualFmin}
    savemat(fname, mdic)
    print("saved DCT bases") 


else:
    print("ERROR - CANNOT COMPUTE DCT WITH configs_EPI_dctfMin = ",configs_EPI_dctfMin)





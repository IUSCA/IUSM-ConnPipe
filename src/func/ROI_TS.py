
import os
import sys
import numpy as np
import nibabel as nib
from scipy.io import savemat
import time


###### print to qc file #######
QCfile_name = ''.join([os.environ['QCfile_name'],'.log'])
fqc=open(QCfile_name, "a+")

print("\n *** python ROI_TS **** ")

NuisancePhysReg_out = os.environ['NuisancePhysReg_out']
print("NuisancePhysReg_out "+ NuisancePhysReg_out)

numParcs = int(os.environ['numParcs'])
print("umParcs "+ str(numParcs))

EPIpath=os.environ['EPIrun_out']
print("PIpath "+ EPIpath)

post_nR=os.environ['post_nR']
print("post_nR "+ post_nR)

dvars_despike=os.environ['configs_EPI_despike']
print("dvars_despike "+ dvars_despike)

# load appropriate residuals
fileIn=sys.argv[1]
print("fileIn ",fileIn)
print("Loading post-regression residuals from ",fileIn)
data = np.load(fileIn) 
if dvars_despike == 'true':
    resid=data['resid_despike']
else:
    resid=data['resid']

### read nifti data
 # find the correct WM mask
fname = ''.join([EPIpath,'/rT1_WM_mask_eroded.nii.gz'])
volWM_vol = np.asanyarray(nib.load(fname).dataobj)
numVoxels = np.count_nonzero(volWM_vol);

volWM_mask = np.logical_not(volWM_vol).astype(int) ## negate array and make int

fname = ''.join([EPIpath,'/rT1_CSF_mask_eroded.nii.gz'])
volCSF_vol = np.asanyarray(nib.load(fname).dataobj)
volCSF_mask = np.logical_not(volCSF_vol).astype(int) ## negate array and make int

fname = ''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
volBrain_vol = np.asanyarray(nib.load(fname).dataobj)
volBrain_mask = (volBrain_vol != 0).astype(int)

mtype = "/TimeSeries_%s" % post_nR

path_EPI_Mats = ''.join([NuisancePhysReg_out,mtype])
CHECK_FOLDER = os.path.isdir(path_EPI_Mats)

# If folder doesn't exist, then create it.
if not CHECK_FOLDER:
    os.makedirs(path_EPI_Mats)
    print("created folder : ", path_EPI_Mats)
else:
    print(path_EPI_Mats, "folder already exists.")

[sizeX,sizeY,sizeZ,numTimePoints] = resid.shape
print("resid shape is ",sizeX,sizeY,sizeZ,numTimePoints)


print(numParcs)


for k in range(1,numParcs+1):
    parc_label=os.environ["PARC%d" % k]
    parc_nodal=os.environ["PARC%dpnodal" % k]
    parc_subcortonly=os.environ["PARC%dpsubcortonly" % k]
    parc_crblmonly=os.environ["PARC%dpcrblmonly" % k]

    if parc_nodal == "1":
        print(" Processing nodes for %s parcellation" % parc_label)

        if parc_crblmonly == "1":
            parcGM_file = ''.join([EPIpath,'/rT1_parc_',parc_label,'_clean.nii.gz'])
        else:
            parcGM_file = ''.join([EPIpath,'/rT1_GM_parc_',parc_label,'_clean.nii.gz'])

        parcGM = np.asanyarray(nib.load(parcGM_file).dataobj)
        parcGM = parcGM * volWM_mask * volCSF_mask * volBrain_mask

        numROIs = int(np.amax(parcGM))
        print(" number of ROIs - ",numROIs)
        ROIs_numVoxels = np.empty((numROIs,1))
    
        restingROIs = np.empty((numROIs,numTimePoints))
        restingROIs[:] = np.NaN
        ROIs_numNans = np.empty((numROIs,numTimePoints))
        ROIs_numNans[:] = np.NaN

        tic = time.perf_counter()
        for roi in range(0,numROIs): 
            voxelsROI = (parcGM == (roi+1))
            ROIs_numVoxels[roi] = np.count_nonzero(voxelsROI)

            print("ROI %d  - %d voxels" % (roi+1, ROIs_numVoxels[roi]))

            if ROIs_numVoxels[roi] > 0:
                
                for tp in range(0,numTimePoints):

                    vol_tp = resid[:,:,:,tp]
                    vx = vol_tp[voxelsROI]
                    restingROIs[roi,tp] = np.nanmean(vx)
                    
                    if np.isnan(restingROIs[roi,tp]):
                        fqc.write("\n WARNING ROI "+str(roi)+" T "+str(tp)+ " is NAN")
                    ROIs_numNans[roi,tp] = np.isnan(vx).sum()
            else:
                fqc.write("\n WARNING ROI "+str(roi)+ " has zero voxels")
                
        toc = time.perf_counter()
        print(toc-tic)


        fileOut = "/6_epi_%s_ROIs.npz" % parc_label
        fileOut = ''.join([path_EPI_Mats,fileOut])

        ## ROIs_numVOxels is the number of voxels belonging to each node in a partition
        ## restingROIs is the average timeseries of each region
        np.savez(fileOut,restingROIs=restingROIs,ROIs_numVoxels=ROIs_numVoxels,ROIs_numNans=ROIs_numNans)
        print("Saved ROI resting data to: ",fileOut)

        fileOut = "/6_epi_%s_ROIs.mat" % parc_label
        fileOut = ''.join([path_EPI_Mats,fileOut])
        print("savign MATLAB file ", fileOut)
        mdic = {"restingROIs":restingROIs,"ROIs_numVoxels":ROIs_numVoxels,"ROIs_numNans":ROIs_numNans}
        savemat(fileOut, mdic)

    else:
        print(" Skipping %s parcellation - Not a nodal parcellation" % parc_label)

fqc.close()


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

function ROI_TS() {
PhReg_path="$1" postfix="$2" python - <<END
import os
import numpy as np
import nibabel as nib
from scipy.io import savemat
import time


###### print to log files #######
QCfile_name = ''.join([os.environ['QCfile_name'],'.log'])
fqc=open(QCfile_name, "a+")
logfile_name = ''.join([os.environ['logfile_name'],'.log'])
flog=open(logfile_name, "a+")

flog.write("\n *** python ROI_TS **** ")
numParcs = int(os.environ['numParcs'])
flog.write("\n numParcs "+ str(numParcs))
PhReg_path = os.environ['PhReg_path']
flog.write("\n PhReg_path "+ PhReg_path)
EPIpath=os.environ['EPIpath']
flog.write("\n EPIpath "+ EPIpath)
nR=os.environ['nR']
flog.write("\n nR "+ nR)
postfix=os.environ['postfix']
flog.write("\n postfix "+ postfix)
numTimePoints = int(os.environ['nvols'])
flog.write("\n numTimePoints "+ str(numTimePoints))

fname = ''.join([PhReg_path,'/NuisanceRegression_',nR,'_output.npz'])
print("loading regressors: ",fname)
data = np.load(fname) 
resid = data['resid']
print("resid shape ",resid[0].shape)


### read nifti data
 # find the correct WM mask
fname = ''.join([EPIpath,'/rT1_WM_mask_eroded.nii.gz'])
volWM_vol = nib.load(fname).get_data()
numVoxels = np.count_nonzero(volWM_vol);

volWM_mask = np.logical_not(volWM_vol).astype(np.int) ## negate array and make int

fname = ''.join([EPIpath,'/rT1_CSF_mask_eroded.nii.gz'])
volCSF_vol = nib.load(fname).get_data()
volCSF_mask = np.logical_not(volCSF_vol).astype(np.int) ## negate array and make int

fname = ''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
volBrain_vol = nib.load(fname).get_data()
volBrain_mask = (volBrain_vol != 0).astype(np.int)

for pc in range(0,len(resid)):

    if len(resid)==1:
        ff = "7_epi_%s.nii.gz" % postfix 
        mtype = "/TimeSeries_%s" % postfix
    else:
        ff = "7_epi_%s%d.nii.gz" % (postfix,pc)
        mtype = "/TimeSeries_%s%d" % (postfix,pc)

    path_EPI_Mats = ''.join([PhReg_path,mtype])
    CHECK_FOLDER = os.path.isdir(path_EPI_Mats)

    # If folder doesn't exist, then create it.
    if not CHECK_FOLDER:
        os.makedirs(path_EPI_Mats)
        print("created folder : ", path_EPI_Mats)
    else:
        print(path_EPI_Mats, "folder already exists.")

    resting_file = ''.join([PhReg_path,'/',ff])
    print("resting file to read is: ",resting_file)
    flog.write("\n resting file to read is: " + resting_file)
    resting = nib.load(resting_file)
    resting_vol = resting.get_data()
    [sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
    print("resting_vol shape is ",sizeX,sizeY,sizeZ,numTimePoints)

    for k in range(0,numParcs+1):
        parc_label=os.environ["PARC%d" % k]
        parc_nodal=os.environ["PARC%dpnodal" % k]
        parc_subcortonly=os.environ["PARC%dpsubcortonly" % k]

        if parc_nodal == "1" and parc_subcortonly == "0":
            print(" Processing nodes for %s parcellation" % parc_label)
            flog.write("\n Processing nodes for %s parcellation"+ parc_label)

            parcGM_file = ''.join([EPIpath,'/rT1_GM_parc_',parc_label,'_clean.nii.gz'])
            parcGM = nib.load(parcGM_file).get_data()
            parcGM = parcGM * volWM_mask * volCSF_mask * volBrain_mask

            numROIs = int(np.amax(parcGM))
            print(" number of ROIs - ",numROIs)
            fqc.write("\n number of ROIs - " + str(numROIs))
            ROIs_numVoxels = np.empty((numROIs,1))
        
            restingROIs = np.empty((numROIs,numTimePoints))
            restingROIs[:] = np.NaN
            ROIs_numNans = np.empty((numROIs,numTimePoints))
            ROIs_numNans[:] = np.NaN

            tic = time.clock()
            for roi in range(0,numROIs): 
                voxelsROI = (parcGM == (roi+1))
                ROIs_numVoxels[roi] = np.count_nonzero(voxelsROI)

                print("ROI %d  - %d voxels" % (roi+1, ROIs_numVoxels[roi]))
                flog.write("\n ROI " + str(roi+1) + " - "+ str(ROIs_numVoxels[roi]) + " voxels")

                if ROIs_numVoxels[roi] > 0:
                    
                    for tp in range(0,numTimePoints):

                        vol_tp = resting_vol[:,:,:,tp]
                        vx = vol_tp[voxelsROI]
                        restingROIs[roi,tp] = np.nanmean(vx)
                        
                        if np.isnan(restingROIs[roi,tp]):
                            fqc.write("\n WARNING ROI "+str(roi)+" T "+str(tp)+ " is NAN")
                        ROIs_numNans[roi,tp] = np.isnan(vx).sum()
                else:
                    fqc.write("\n WARNING ROI "+str(roi)+" T "+str(tp)+ " has zero voxels")
                    
            toc = time.clock()
            print(toc-tic)


            fileOut = "/8_epi_%s_ROIs.npz" % parc_label
            fileOut = ''.join([path_EPI_Mats,fileOut])

            ## ROIs_numVOxels is the number of voxels belonging to each node in a partition
            ## restingROIs is the average timeseries of each region
            np.savez(fileOut,restingROIs=restingROIs,ROIs_numVoxels=ROIs_numVoxels,ROIs_numNans=ROIs_numNans)
            print("Saved ROI resting data to: ",fileOut)
            flog.write("\n Saved ROI resting data to: "+fileOut)

            fileOut = "/8_epi_%s_ROIs.mat" % parc_label
            fileOut = ''.join([path_EPI_Mats,fileOut])
            print("savign MATLAB file ", fileOut)
            mdic = {"restingROIs":restingROIs,"ROIs_numVoxels":ROIs_numVoxels,"ROIs_numNans":ROIs_numNans}
            savemat(fileOut, mdic)

        else:
            print(" Skipping %s parcellation - Not a nodal parcellation" % parc_label)
            flog.write("\n Skipping "+parc_label+" - Not a nodal parcellation")

fqc.close()
flog.close()

END
}


###################################################################################


log "# =========================================================="
log "# 8. ROIs. "
log "# =========================================================="



PhReg_path="${EPIpath}/${regPath}"

if ${flags_EPI_BandPass}; then 
    postfix="${nR}_Butter"
else
    postfix="${nR}"
fi 



ROI_TS ${PhReg_path} ${postfix}


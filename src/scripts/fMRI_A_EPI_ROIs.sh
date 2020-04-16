
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
PhReg_path="$1" python - <<END
import os
import numpy as np
import nibabel as nib

numParcs = int(os.environ['numParcs'])
print("numParcs is ",numParcs)
PhReg_path = os.environ['PhReg_path']
print("PhReg_path is ",PhReg_path)
EPIpath=os.environ['EPIpath']
print("EPIpath ",EPIpath)
postfix=os.environ['nR']
print("postfix ",postfix)
resting_file=os.environ['configs_EPI_resting_file']
print("resting_file ",resting_file)

fname_dmdt = ''.join([PhReg_path,'/NuisanceRegression_',postfix,'_output_dmdt.npz'])
data_dmdt = np.load(fname_dmdt) 
resid = data_dmdt['resid']
print("resid shape ",resid[0].shape)


# read nifti data
fname = ''.join([EPIpath,'/rT1_WM_mask_eroded.nii.gz'])
volWM_vol = nib.load(fname).get_data()
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
    resting = nib.load(resting_file)
    resting_vol = resting.get_data()
    [sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
    print("resting_vol shape is ",sizeX,sizeY,sizeZ,numTimePoints)

    for k in range(0,numParcs):
        parc_label=os.environ["PARC%d" % k]
        parc_nodal=os.environ["PARC%dpnodal" % k]

        if parc_nodal == "1":
            print(" Processing nodes for %s parcellation" % parc_label)

            parcGM_file = ''.join([EPIpath,'/rT1_GM_parc_',parc_label,'_clean.nii.gz'])
            parcGM = nib.load(parcGM_file).get_data()
            parcGM = parcGM * volWM_mask * volCSF_mask * volBrain_mask

            numROIs = int(np.amax(parcGM))
            print(" number of ROIs - ",numROIs)
            ROIs_numVoxels = np.empty((numROIs,1))

            for i_roi in range(0,numROIs):
                ROIs_numVoxels[i_roi] = np.count_nonzero((parcGM == (i_roi+1)))
                print("ROI %d  - %d voxels" % (i_roi+1, ROIs_numVoxels[i_roi]))
        
            restingROIs = np.zeros((numROIs,numTimePoints))
            ROIs_numNans = np.empty((numROIs,numTimePoints))
            ROIs_numNans[:] = np.NaN

            for tp in range(0,numTimePoints):
                vol_tp = resting_vol[:,:,:,tp]

                for roi in range(0,numROIs): 
                    voxelsROI = (parcGM == (roi+1)) 
                    ## boolean true elements get ignored so we must negate the mask
                    voxelsROI_mask = np.logical_not(voxelsROI) 
                    vx = np.ma.array(vol_tp,mask=voxelsROI_mask)
                    restingROIs[roi,tp] = np.nanmean(vx)
                    ROIs_numNans[roi,tp] = np.isnan(vx).sum()

                if tp % 20 == 0:
                    print("%d out of %d" % (tp, numTimePoints))


            fileOut = "/8_epi_%s_ROIs.npz" % parc_label
            fileOut = ''.join([path_EPI_Mats,fileOut])

            ## ROIs_numVOxels is the number of voxels belonging to each node in a partition
            ## restingROIs is the average timeseries of each region
            np.savez(fileOut,restingROIs=restingROIs,ROIs_numVoxels=ROIs_numVoxels,ROIs_numNans=ROIs_numNans)
            print("Saved ROI resting data to: ",fileOut)

        else:
            print(" Skipping %s parcellation - Not a nodal parcellation" % parc_label)
END
}


###################################################################################


echo "# =========================================================="
echo "# 8. ROIs. "
echo "# =========================================================="



PhReg_path="${EPIpath}/${regPath}"
fileIn="${PhReg_path}/NuisanceRegression_${nR}_output.npz"
fileIn_dmdt="${PhReg_path}/NuisanceRegression_${nR}_output_dmdt.npz"


ROI_TS ${PhReg_path}


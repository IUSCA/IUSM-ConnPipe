
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

function apply_reg() {
EPIpath="$1" nuisanceReg="$2" config_param="$3" numReg="$4" numGS="$5" physReg="$6" scrub="$7" postfix="$8" resting_file="$9" python - <<END
import os
import numpy as np
import nibabel as nib
from scipy import stats

def apply_reg(data, mask, regressors,scrubbing):

    # remove identical regressors (rows) if present
    #unique_regressors = np.vstack({tuple(row) for row in regressors})
    print("regressors shape before removing uniques ",regressors.shape)
    unique_regressors = [tuple(row) for row in regressors]
    unique_regressors = np.unique(unique_regressors, axis=0)
    print("unique_regressors shape after removing repeated rows ",unique_regressors.shape)

    [sizeX,sizeY,sizeZ,numTimePoints] = data.shape
    resid = np.zeros(data.shape)

    for i in range(0,sizeX):
        for j in range(0,sizeY):
            for k in range(0,sizeZ):
                if mask[i,j,k]:
                    TSvoxel = data[i,j,k]                                            
                    B = np.linalg.lstsq(unique_regressors.T,TSvoxel,rcond=None)
                    coeffs = B[0]
                    Yhat = np.sum(np.multiply(coeffs[:,None],unique_regressors),axis=0)
                    resid[i,j,k,:] = TSvoxel - Yhat
        if i % 25 == 0:
            print("--", i/sizeX, "-- done")

    return resid

###### print to log files #######
QCfile_name=os.environ['QCfile_name']
QCfile_name = ''.join([QCfile_name,'.log'])
print("QCfile_name: ",QCfile_name)
fqc=open(QCfile_name, "a+")

logfile_name=os.environ['logfile_name']
logfile_name = ''.join([logfile_name,'.log'])
print("logfile_name: ",logfile_name)
flog=open(logfile_name, "a+")

EPIpath=os.environ['EPIpath']
nuisanceReg=os.environ['nuisanceReg']
flog.write("\n"+"nuisanceReg "+ nuisanceReg)
config_param=int(os.environ['config_param'])
flog.write("\n"+"config_param "+ str(config_param))
numReg=int(os.environ['numReg'])
flog.write("\n"+"numReg "+ str(numReg))
numGS=int(os.environ['numGS'])
flog.write("\n"+"numGS "+ str(numGS))
physReg=os.environ['physReg']
flog.write("\n"+"physReg "+ physReg)
PhReg_path = ''.join([EPIpath,'/',nuisanceReg,'/',physReg])
flog.write("\n"+"PhReg_path "+ PhReg_path )
postfix=os.environ['postfix']
flog.write("\n"+"postfix "+ postfix)
scrub=os.environ['scrub']
flog.write("\n"+"scrub "+ scrub)
resting_file=os.environ['resting_file']
flog.write("\n"+"resting_file "+ resting_file)
resting_file = ''.join([EPIpath,resting_file]) 
flog.write("\n"+"full resting file is "+ resting_file)

flog.write("\n REGRESSORS -- Creating regressor matrix with the follwing:")


if nuisanceReg == "AROMA":
    print("1. Applying AROMA regressors")
    flog.write("\n 1. Applying AROMA regressors")
    regressors = np.array([])

elif nuisanceReg == "HMPreg":
    print("1. Applying Head Motion Param regressors") 
    flog.write("\n 1. Applying Head Motion Param regressors")

    if numReg == 24:
        print(" -- 24 Head motion regressors")
        flog.write("\n  -- 24 Head motion regressors")
        fname=''.join([EPIpath,'/HMPreg/motion12_regressors.npz'])
        m12reg = np.load(fname)
        print(sorted(m12reg.files))
        fname=''.join([EPIpath,'/HMPreg/motion_sq_regressors.npz'])
        m_sq_reg = np.load(fname)  
        print(sorted(m_sq_reg.files))
        regressors = np.vstack((m12reg['motion'].T,m12reg['motion_deriv'].T,m_sq_reg['motion_sq'].T,m_sq_reg['motion_deriv_sq'].T))
    elif numReg == 12:
        print(" -- 12 Head motion regressors")
        flog.write("\n -- 12 Head motion regressors")
        fname=''.join([EPIpath,'/HMPreg/motion12_regressors.npz'])
        m12reg = np.load(fname)
        print(sorted(m12reg.files))
        regressors = np.vstack((m12reg['motion'].T,m12reg['motion_deriv'].T))

flog.write("\n regressors shape " + str(regressors.shape))

if numGS > 0:
    fname = ''.join([PhReg_path,'/dataGS.npz'])
    dataGS = np.load(fname) 
    if numGS == 1:
        gsreg = dataGS['GSavg']
        if regressors.size:
            regressors = np.vstack((regressors,gsreg))
        else:
            regressors = gsreg 
        print("   -- 1 global signal regressor ")
        flog.write("\n  -- 1 global signal regressor )
        print("regressors shape ",regressors.shape)
        flog.write("\n regressors shape " + str(regressors.shape))
    if numGS == 2:
        gsreg = np.vstack((dataGS['GSavg'],dataGS['GSderiv']))
        if regressors.size:
            regressors = np.vstack((regressors,gsreg))
        else:
            regressors = gsreg    
        
        print("   -- 2 global signal regressor ")
        flog.write("\n  -- 2 global signal regressor )
        print("regressors shape ",regressors.shape)
        flog.write("\n regressors shape " + str(regressors.shape))
    if numGS == 4:
        gsreg = np.vstack((dataGS['GSavg'],\
                           dataGS['GSavg_sq'],\
                           dataGS['GSderiv'],\
                           dataGS['GSderiv_sq']))        
        if regressors.size:
            regressors = np.vstack((regressors,gsreg))
        else:
            regressors = gsreg

        print("   -- 4 global signal regressor ")   
        flog.write("\n  -- 4 global signal regressor )
        print("regressors shape ",regressors.shape)  
        flog.write("\n regressors shape " + str(regressors.shape))           


if physReg == "aCompCorr":
    fname = ''.join([PhReg_path,'/dataPCA_WM-CSF.npz'])
    numphys = np.load(fname) 
    print("-- aCompCor PC of WM & CSF regressors")
    zRegressMat = [];
    if config_param > 5:
        print("  -- Applying all levels of PCA removal")
        for ic in range(6):
            if ic == 0:
                zRegressMat.append(stats.zscore(regressors,axis=1));                
            else:
                regMat = np.vstack((regressors,\
                                        numphys['CSFpca'][:,:ic].T,\
                                        numphys['WMpca'][:,:ic].T))
                zRegressMat.append(stats.zscore(regMat,axis=1));
                print("    -- PCA %d" % ic)


    elif 0 < config_param < 6:
        print("-- Writing prespecified removal of %d components ----" % config_param)
        print("regressors shape ",regressors.shape)

        # Ensure that we have all CSF needed components
        print("numphys['CSFpca'] shape ",numphys['CSFpca'].shape)
        if numphys['CSFpca'].ndim == 2:
            csf = numphys['CSFpca'][:,:config_param].T
            print("--- Using CSF PC number %d" % config_param)
        else:  # PCS failed and we used the mean signal and CSFpca is a singleton
            csf = numphys['CSFpca'][None,:]
            print("--- Using CSF mean signal")

        # Ensure that we have all needed WM components
        print("numphys['WMpca'] shape ",numphys['WMpca'].shape)
        if numphys['WMpca'].ndim == 2:
            wm = numphys['WMpca'][:,:config_param].T
            print("--- Using WM PC number %d" % config_param)
        else:  # WM PCA failed and we used the mean signal
            wm = numphys['WMpca'][None,:]
            print("--- Using WM mean signal")

        components = np.vstack((regressors,\
                                csf,\
                                wm))

        print("components shape: ", components.shape)
        zRegressMat.append(stats.zscore(components,axis=1));
        print("    -- PCA 1 through %d" % config_param)

elif physReg == "PhysReg":
    fname = ''.join([PhReg_path,'/dataMnRg_WM-CSF.npz'])
    numphys = np.load(fname) 
    print(numphys['CSFavg'].shape)
    print(numphys['WMavg'].shape)
    
    if config_param == 2:
        regressors = np.vstack((regressors,\
                                numphys['CSFavg'],\
                                numphys['WMavg']))
        print("   -- 2 physiological regressors ")
        print("regressors shape ",regressors.shape)
    if config_param == 4:
        regressors = np.vstack((regressors,\
                                numphys['CSFavg'],numphys['CSFderiv'],\
                                numphys['WMavg'],numphys['WMderiv']))        
        print("   -- 4 physiological regressors")
        print("regressors shape ",regressors.shape)
    if config_param == 8:
        regressors = np.vstack((regressors,\
                                numphys['CSFavg'],numphys['CSFavg_sq'],\
                                numphys['CSFderiv'],numphys['CSFderiv_sq'],\
                                numphys['WMavg'],numphys['WMavg_sq'],\
                                numphys['WMderiv'],numphys['WMderiv_sq'])) 
        print("   -- 8 physiological regressors ")   
        print("regressors shape ",regressors.shape) 
    
    zRegressMat = [];
    zRegressMat.append(stats.zscore(regressors,axis=0));


## regress-out motion/physilogical regressors 
print("2. Applying motion/physicological regression")

# load resting vol
resting = nib.load(resting_file)
resting_vol = resting.get_data()
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
print("resting_vol.shape ", sizeX,sizeY,sizeZ,numTimePoints)

# load GS mask
fname = ''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
volGS = nib.load(fname)
volGS_vol = volGS.get_data()

for i in range(0,numTimePoints):
    rv = resting_vol[:,:,:,i]
    rv[volGS_vol==0]=0
    resting_vol[:,:,:,i] = rv

volBrain_file = ''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
volBrain = nib.load(volBrain_file)
volBrain_vol = volBrain.get_data()

if scrub == 'true' and nuisanceReg == "HMPreg":
    fname=''.join([EPIpath,'/scrubbing_goodvols.npz'])
    scrubvar = np.load(fname) 
    scrubvar = scrubvar['scrub']
else:
    scrubvar = np.ones(numTimePoints, dtype=int)

resid = []
for r in range(0,len(zRegressMat)):
    rr = apply_reg(resting_vol,volBrain_vol,zRegressMat[r],scrubvar)
    resid.append(rr)

## save data (for header info), regressors, and residuals
fname = ''.join([PhReg_path,'/NuisanceRegression_',postfix,'_output.npz'])
np.savez(fname,resting_vol=resting_vol,volBrain_vol=volBrain_vol,zRegressMat=zRegressMat,resid=resid,postfix=postfix)
print("Saved aCompCor PCA regressors")


END
}


##############################################################################

## PHYSIOLOGICAL REGRESSORS
echo "# =========================================================="
echo "# 5.3 APPLY REGRESSORS "
echo "# =========================================================="

if ${flags_NuisanceReg_AROMA}; then
    log "nuisanceReg AROMA"
    nuisanceReg="AROMA"
    configs_EPI_numReg=0
    configs_EPI_scrub=false
elif ${flags_NuisanceReg_HeadParam}; then
    log "nuisanceReg HMParam"
    nuisanceReg="HMPreg"  
fi


if [[ ! ${flags_EPI_GS} ]]; then
    configs_EPI_numGS=0
fi


if ${flags_PhysiolReg_aCompCorr}; then  
    log "PhysiolReg - aCompCorr"
    physReg="aCompCorr"
    config_param=${configs_EPI_numPC}

elif ${flags_PhysiolReg_WM_CSF}; then
    log "PhysiolReg - Mean CSF & WM signal"
    physReg="PhysReg" #"Mn_WM_CSF"
    config_param=${configs_EPI_numPhys}    
fi 


log "filename postfix for output image -- ${nR}"


log "calling python script"
cmd="apply_reg ${EPIpath} \
    ${nuisanceReg} ${config_param} \
    ${configs_EPI_numReg} ${configs_EPI_numGS} \
    ${physReg} ${configs_EPI_scrub} ${nR} ${configs_EPI_resting_file}"
log $cmd
eval $cmd      

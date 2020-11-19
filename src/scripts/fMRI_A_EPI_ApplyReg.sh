
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

print("inside Python script")

def apply_reg(data, mask, regressors,scrubbing):

    # remove identical regressors (rows) if present
    unique_regressors = np.vstack({tuple(row) for row in regressors})
    [sizeX,sizeY,sizeZ,numTimePoints] = data.shape
    resid = np.zeros(data.shape)

    for i in range(0,sizeX):
        for j in range(0,sizeY):
            for k in range(0,sizeZ):
                if mask[i,j,k]:
                    TSvoxel = data[i,j,k]                                            
                    B = np.linalg.lstsq(unique_regressors.T,TSvoxel)
                    coeffs = B[0]
                    Yhat = np.sum(np.multiply(coeffs[:,None],unique_regressors),axis=0)
                    resid[i,j,k,:] = TSvoxel - Yhat
        if i % 25 == 0:
            print("--", i/sizeX, "-- done")

    return resid

EPIpath=os.environ['EPIpath']
nuisanceReg=os.environ['nuisanceReg']
print("nuisanceReg",nuisanceReg)
config_param=int(os.environ['config_param'])
print("config_param",config_param)
numReg=int(os.environ['numReg'])
print("numReg",numReg)
numGS=int(os.environ['numGS'])
print("numGS",numGS)
physReg=os.environ['physReg']
print("physReg",physReg)
PhReg_path = ''.join([EPIpath,'/',nuisanceReg,'/',physReg])
print("PhReg_path ",PhReg_path )
postfix=os.environ['postfix']
print("postfix",postfix)
scrub=os.environ['scrub']
print("scrub",scrub)
resting_file=os.environ['resting_file']
print("resting_file",resting_file)
resting_file = ''.join([EPIpath,resting_file]) 
print("full resting file is ",resting_file)

print("REGRESSORS -- Creating regressor matrix with the follwing:")


if nuisanceReg == "AROMA":
    print("1. Applying AROMA regressors")
    regressors = np.array([])

elif nuisanceReg == "HMPreg":
    print("1. Applying Head Motion Param regressors") 

    if numReg == 24:
        print(" -- 24 Head motion regressors")
        fname=''.join([EPIpath,'/HMPreg/motion12_regressors.npz'])
        m12reg = np.load(fname)
        print(sorted(m12reg.files))
        fname=''.join([EPIpath,'/HMPreg/motion_sq_regressors.npz'])
        m_sq_reg = np.load(fname)  
        print(sorted(m_sq_reg.files))
        regressors = np.vstack((m12reg['motion'].T,m12reg['motion_deriv'].T,m_sq_reg['motion_sq'].T,m_sq_reg['motion_deriv_sq'].T))
        print("regressors shape ",regressors.shape)
    elif numReg == 12:
        print(" -- 12 Head motion regressors")
        fname=''.join([EPIpath,'/HMPreg/motion12_regressors.npz'])
        m12reg = np.load(fname)
        print(sorted(m12reg.files))
        regressors = np.vstack((m12reg['motion'].T,m12reg['motion_deriv'].T))
        print("regressors shape ",regressors.shape)


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
        print("regressors shape ",regressors.shape)
    if numGS == 2:
        gsreg = np.vstack((dataGS['GSavg'],dataGS['GSderiv']))
        if regressors.size:
            regressors = np.vstack((regressors,gsreg))
        else:
            regressors = gsreg    
        
        print("   -- 2 global signal regressor ")
        print("regressors shape ",regressors.shape)
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
        print("regressors shape ",regressors.shape)             


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
        print("numphys['CSFpca'] shape ",numphys['CSFpca'].shape)
        print("numphys['WMpca'] shape ",numphys['WMpca'].shape)

        components = np.vstack((regressors,\
                                numphys['CSFpca'][:,:config_param].T,\
                                numphys['WMpca'][:,:config_param].T))

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
print("Applying motion/physicological regression")

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

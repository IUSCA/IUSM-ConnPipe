
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
EPIpath="$1" nuisanceReg="$2" config_param="$3" numReg="$4" numGS="$5" physReg="$6" scrub="$7" postfix="$8" ${python3_7} - <<END
import os
import numpy as np
import nibabel as nib
from scipy import stats

print("inside Python script")


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

print("REGRESSORS -- Creating regressor matrix with the follwing:")

volBrain_file = ''.join([EPIpath,'rT1_brain_mask_FC.nii.gz'])

if nuisanceReg == "AROMA":
    print("1. Applying AROMA regressors")
    resting_file = ''.join([EPIpath,'/AROMA/AROMA-output/denoised_func_data_nonaggr.nii.gz'])
    regressors = np.array([])

elif nuisanceReg == "HMPreg":
    print("1. Applying Head Motion Param regressors")
    resting_file = ''.join([EPIpath,'/4_epi.nii.gz'])    

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
        print("-- Writing prespecified removal of %d components" % config_param)
        components = np.vstack((regressors,\
                                numphys['CSFpca'][:,:config_param].T,\
                                numphys['WMpca'][:,:config_param].T))
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



END
}


##############################################################################

## PHYSIOLOGICAL REGRESSORS
echo "# =========================================================="
echo "# 5.3 APPLY REGRESSORS "
echo "# =========================================================="

### THIS HAS TO BE UNCOMMNETED; IT IS COMMENTED NOW TO AVOID HAVING TO RUN NUISANCE REG
# if ${flags_EPI_NuisanceReg}; then
    if ${flags_NuisanceReg_AROMA}; then
        log "nuisanceReg AROMA"
        nuisanceReg="AROMA"
        configs_EPI_numReg=0
        configs_EPI_scrub=false
        nR="aroma"   # set filename postfix for output image
    elif ${flags_NuisanceReg_HeadParam}; then
        log "nuisanceReg HMParam"
        nuisanceReg="HMPreg"  
        nR="hmp${configs_EPI_numReg}"   # set filename postfix for output image
        if ${configs_EPI_scrub}; then
            nR="scrubbed_${nR}"
        fi
    fi
# else 
#     nuisanceReg="none"
#     configs_EPI_numReg=0
#     configs_EPI_scrub=false
# fi 

if [[ ! ${flags_EPI_GS} ]]; then
    configs_EPI_numGS=0
else 
    nR="${nR}_Gs${configs_EPI_numGS}"
fi


# if ${flags_EPI_PhysiolReg}; then
    if ${flags_PhysiolReg_aCompCorr}; then  
        log "PhysiolReg - aCompCorr"
        physReg="aCompCorr"
        config_param=${configs_EPI_numPC}
        if [[ "${configs_EPI_numPC}" -ge 0 && "${configs_EPI_numPC}" -le 6 ]]; then
            nR="${nR}_pca${configs_EPI_numPC}"
        elif [[ "${configs_EPI_numPC}" -ge 5 ]]; then
            nR="${nR}_pca"
        fi 
    elif ${flags_PhysiolReg_WM_CSF}; then
        log "PhysiolReg - Mean CSF & WM signal"
        physReg="PhysReg" #"Mn_WM_CSF"
        config_param=${configs_EPI_numPhys}
        nR="${nR}_mPhys${configs_EPI_numPhys}"
    fi 
# else
#     physReg="none"
#     config_param=0
# fi


log "filename postfix for output image -- ${nR}"


log "calling python script"
cmd="apply_reg ${EPIpath} \
    ${nuisanceReg} ${config_param} \
    ${configs_EPI_numReg} ${configs_EPI_numGS} \
    ${physReg} ${configs_EPI_scrub} ${nR}"
log $cmd
eval $cmd      

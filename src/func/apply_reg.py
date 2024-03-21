
import os
import sys
import numpy as np
import nibabel as nib
from scipy import stats
from scipy.io import savemat

def f_apply_reg(data, mask, regressors):

    # remove identical regressors (rows) if present
    print("regressors shape before removing uniques ",regressors.shape)
    unique_regressors = [tuple(row) for row in regressors]
    unique_regressors = np.unique(unique_regressors, axis=0)
    print("unique_regressors shape after removing repeated rows ",unique_regressors.shape)

    [sizeX,sizeY,sizeZ,numTimePoints] = data.shape
    resid = np.zeros(data.shape)

    unique_regressors = np.vstack((np.ones((1, numTimePoints)), unique_regressors))
    print("unique_regressors shape after adding intercept ",unique_regressors.shape)

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
QCfile_name = ''.join([os.environ['QCfile_name'],'.log'])
fqc=open(QCfile_name, "a+")
logfile_name = ''.join([os.environ['logfile_name'],'.log'])
flog=open(logfile_name, "a+")

flog.write("\n *** python apply_reg **** ")
EPIpath=os.environ['EPIrun_out']

nuisanceReg=sys.argv[1]  
print("nuisanceReg is ",nuisanceReg)
flog.write("\n nuisanceReg "+ nuisanceReg)

physReg=sys.argv[2] 
print("physReg is ",physReg)
flog.write("\n physReg "+ physReg)
NuisancePhysReg_out = ''.join([EPIpath,'/',nuisanceReg,'/',physReg])
print("NuisancePhysReg_out is ",NuisancePhysReg_out)
flog.write("\n NuisancePhysReg_out "+ NuisancePhysReg_out )

config_param=int(os.environ['configs_EPI_numPhys'])
print("config_param is ",config_param)
flog.write("\n config_param "+ str(config_param))

numReg=int(os.environ['configs_EPI_numReg'])
flog.write("\n numReg "+ str(numReg))
print("numReg is ",numReg)

numGS=int(os.environ['configs_EPI_numGS'])
flog.write("\n numGS "+ str(numGS))
print("numGS is ",numGS)

nR=os.environ['nR']
flog.write("\n nR "+ nR)
print("nR is ",nR)
# If BPF is set, need to crop nR, since BPF doesnt get done until after nuissance regressison.
if nR.endswith("_BPF"):
    nRc=nR[:-4]
else:
    nRc=nR

dvars_despike=os.environ['configs_EPI_despike']
flog.write("\n dvars_despike "+ dvars_despike)

resting_file=os.environ['configs_EPI_resting_file']
flog.write("\n resting_file "+ resting_file)
resting_file = ''.join([EPIpath,resting_file]) 
flog.write("\n full resting file is "+ resting_file)

dctfMin=float(os.environ['configs_EPI_dctfMin'])
flog.write("\n dctfMin "+ str(dctfMin))


flog.write("\n REGRESSORS -- Creating regressor matrix with the following:") 

if nuisanceReg == "AROMA":
    print("1. Using AROMA cleaned data")
    flog.write("\n 1. Using AROMA cleaned data")
    regressors = np.array([])

elif nuisanceReg == "HMPreg" or nuisanceReg == "AROMA_HMP":
    print("1. Applying Head Motion Param regressors") 
    flog.write("\n 1. Applying Head Motion Param regressors")

    if numReg == 24:
        print(" -- 24 Head motion regressors")
        flog.write("\n  -- 24 Head motion regressors")
        fname=''.join([EPIpath,'/',nuisanceReg,'/motion12_regressors.npz'])
        m12reg = np.load(fname)
        print(sorted(m12reg.files))
        fname=''.join([EPIpath,'/',nuisanceReg,'/motion_sq_regressors.npz'])
        m_sq_reg = np.load(fname)  
        print(sorted(m_sq_reg.files))
        regressors = np.vstack((m12reg['motion'].T,m12reg['motion_deriv'].T,m_sq_reg['motion_sq'].T,m_sq_reg['motion_deriv_sq'].T))
    elif numReg == 12:
        print(" -- 12 Head motion regressors")
        flog.write("\n -- 12 Head motion regressors")
        fname=''.join([EPIpath,'/',nuisanceReg,'/motion12_regressors.npz'])
        m12reg = np.load(fname)
        print(sorted(m12reg.files))
        regressors = np.vstack((m12reg['motion'].T,m12reg['motion_deriv'].T))

flog.write("\n regressors shape " + str(regressors.shape))

if numGS > 0:
    fname = ''.join([NuisancePhysReg_out,'/dataGS.npz'])
    dataGS = np.load(fname) 
    if numGS == 1:
        gsreg = dataGS['GSavg']
        if regressors.size:
            regressors = np.vstack((regressors,gsreg))
        else:
            regressors = gsreg 
        print("   -- 1 global signal regressor ")
        flog.write("\n  -- 1 global signal regressor ")
        print("regressors shape ",regressors.shape)
        flog.write("\n regressors shape " + str(regressors.shape))
    if numGS == 2:
        gsreg = np.vstack((dataGS['GSavg'],dataGS['GSderiv']))
        if regressors.size:
            regressors = np.vstack((regressors,gsreg))
        else:
            regressors = gsreg    
        
        print("   -- 2 global signal regressor ")
        flog.write("\n  -- 2 global signal regressor ")
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
        flog.write("\n  -- 4 global signal regressor ")
        print("regressors shape ",regressors.shape)  
        flog.write("\n regressors shape " + str(regressors.shape)) 


# k DCT filtering
if dctfMin > 0:
    fname = ''.join([NuisancePhysReg_out,'/dataDCT.npz'])
    dataDCT = np.load(fname) 
    dctreg = dataDCT['dct'].T
    numDCT = dataDCT['numDCT']
    print("dctreg shape is ", dctreg.shape)
    if regressors.size:
        regressors = np.vstack((regressors,dctreg))
    else:
        regressors = dctreg 
    print("   -- ",numDCT, " Discrete Cosine Transform basis ")
    flog.write("\n  -- " + str(numDCT) + " Discrete Cosine Transform basis ")
    print("regressors shape ",regressors.shape)
    flog.write("\n regressors shape " + str(regressors.shape))


if physReg == "aCompCor":
    fname = ''.join([NuisancePhysReg_out,'/dataPCA',str(config_param),'_WM-CSF.npz'])
    numphys = np.load(fname) 
    print("-- aCompCor PC of WM & CSF regressors")
    flog.write("\n -- aCompCor PC of WM & CSF regressors" )
    zRegressMat = []

    if config_param > 5:
        print("  -- Applying all levels of PCA removal")
        flog.write("\n -- Applying all levels of PCA removal" )
        for ic in range(6):
            if ic == 0:
                zRegressMat.append(stats.zscore(regressors,axis=1));                
            else:
                regMat = np.vstack((regressors,\
                                        numphys['CSFpca'][:ic,:],\
                                        numphys['WMpca'][:ic,:]))
                zRegressMat.append(stats.zscore(regMat,axis=1));
                print("    -- PCA %d" % ic)
                flog.write("\n    -- PCA " + str(ic))

    elif 0 < config_param < 6:
        print("-- Writing prespecified removal of %d components ----" % config_param)
        flog.write("\n -- Writing prespecified removal of " + str(config_param) + " components")
        print("regressors shape ",regressors.shape)

        # Ensure that we have all CSF needed components
        print("numphys['CSFpca'] shape ",numphys['CSFpca'].shape)
        flog.write("\n CSFpca shape " + str(numphys['CSFpca'].shape))
        if numphys['CSFpca'].ndim == 2:
            csf = numphys['CSFpca'][:config_param,:]
            print("--- Using CSF PC number %d" % config_param)
            flog.write("\n--- Using CSF PC number " + str(config_param))
        else:  # PCS failed and we used the mean signal and CSFpca is a singleton
            csf = numphys['CSFpca']
            print("--- Using CSF mean signal")
            flog.write("\n--- Using CSF mean signal")
        print("csf shape ",csf.shape)

        # Ensure that we have all needed WM components
        print("numphys['WMpca'] shape ",numphys['WMpca'].shape)
        flog.write("\n WMpca shape " + str(numphys['WMpca'].shape))
        if numphys['WMpca'].ndim == 2:
            wm = numphys['WMpca'][:config_param,:]
            print("--- Using WM PC number %d" % config_param)
            flog.write("\n--- Using WM PC number " + str(config_param))
        else:  # WM PCA failed and we used the mean signal
            wm = numphys['WMpca']
            print("--- Using WM mean signal")
            flog.write("\n--- Using WM mean signal")

        print("wm shape ",wm.shape)

        if regressors.size:
             components = np.vstack((regressors,\
                                    csf,\
                                    wm))
        else:
            components = np.vstack((csf,\
                                    wm))

        print("components shape: ", components.shape)
        flog.write("\n components shape " + str(components.shape))
        zRegressMat.append(stats.zscore(components,axis=1))
        print("    -- PCA 1 through %d" % config_param)
        flog.write("\n    -- PCA 1 through " + str(config_param))

elif physReg == "meanPhysReg":
    fname = ''.join([NuisancePhysReg_out,'/dataMnRg_WM-CSF.npz'])
    numphys = np.load(fname) 
    flog.write("\n numphys[CSFavg].shape " + str(numphys['CSFavg'].shape))
    flog.write("\n numphys[WMavg].shape " + str(numphys['WMavg'].shape))
    
    if config_param == 2:
        if regressors.size:
            regressors = np.vstack((regressors,\
                                numphys['CSFavg'],\
                                numphys['WMavg']))
        else:
            regressors = np.vstack((numphys['CSFavg'],\
                                numphys['WMavg']))  
        print("   -- 2 physiological regressors ")
        flog.write("\n    -- 2 physiological regressors ")
        print("regressors shape ",regressors.shape)
        flog.write("\n regressors shape " + str(regressors.shape))
    if config_param == 4:
        if regressors.size:
            regressors = np.vstack((regressors,\
                                numphys['CSFavg'],numphys['CSFderiv'],\
                                numphys['WMavg'],numphys['WMderiv'])) 
        else:
            regressors = np.vstack((numphys['CSFavg'],numphys['CSFderiv'],\
                                numphys['WMavg'],numphys['WMderiv']))       
        print("   -- 4 physiological regressors")
        flog.write("\n    -- 4 physiological regressors ")
        print("regressors shape ",regressors.shape)
        flog.write("\n regressors shape " + str(regressors.shape))
    if config_param == 8:
        if regressors.size:
            regressors = np.vstack((regressors,\
                                numphys['CSFavg'],numphys['CSFavg_sq'],\
                                numphys['CSFderiv'],numphys['CSFderiv_sq'],\
                                numphys['WMavg'],numphys['WMavg_sq'],\
                                numphys['WMderiv'],numphys['WMderiv_sq'])) 
        else:
            regressors = np.vstack((numphys['CSFavg'],numphys['CSFavg_sq'],\
                                numphys['CSFderiv'],numphys['CSFderiv_sq'],\
                                numphys['WMavg'],numphys['WMavg_sq'],\
                                numphys['WMderiv'],numphys['WMderiv_sq'])) 
        print("   -- 8 physiological regressors ")   
        flog.write("\n    -- 8 physiological regressors ")
        print("regressors shape ",regressors.shape) 
        flog.write("\n regressors shape " + str(regressors.shape))
    
    zRegressMat = []
    zRegressMat.append(stats.zscore(regressors,axis=1))


## regress-out motion/physilogical regressors 
print("2. Applying motion/physicological regression")
flog.write("\n 2. Applying motion/physicological regression")

# load resting vol
resting = nib.load(resting_file)
resting_vol = np.asanyarray(resting.dataobj)
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
print("resting_vol.shape ", sizeX,sizeY,sizeZ,numTimePoints)

# load GS mask
volBrain_file = ''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
volBrain = nib.load(volBrain_file)
volBrain_vol = np.asanyarray(volBrain.dataobj)

for i in range(0,numTimePoints):
    rv = resting_vol[:,:,:,i]
    rv[volBrain_vol==0]=0
    resting_vol[:,:,:,i] = rv


resid = []

# this loop is if all pc steps for acompcor are written out
# otherwise zRegressMat is length 1
for r in range(0,len(zRegressMat)):

    rr = f_apply_reg(resting_vol,volBrain_vol,zRegressMat[r])

    resid.append(rr)

    # save nifti image
    if len(zRegressMat)==1:
        fileOut = "/7_epi_%s.nii.gz" % nRc 
    else:
        fileOut = "/7_epi_%s%d.nii.gz" % (nRc,pc)

    fileOut = ''.join([NuisancePhysReg_out,fileOut])
    print("Nifti file to be saved is: ",fileOut)

    # save new resting file
    resting_new = nib.Nifti1Image(rr.astype(np.float32),resting.affine,resting.header)
    nib.save(resting_new,fileOut) 

## Calculate DVARS after regression
print("=== Calculating DVARS from residuals ===")
configs_EPI_path2DVARS=os.environ['configs_EPI_path2DVARS']
flog.write("\n configs_EPI_path2DVARS "+ str(configs_EPI_path2DVARS))
print("configs_EPI_path2dvars ",configs_EPI_path2DVARS)

# Define file name where DVARS info will be printed
fname = ''.join([NuisancePhysReg_out,'/DVARS_',nRc,'.txt'])
fdvars=open(fname, "a+")

import sys
sys.path.append(configs_EPI_path2DVARS)
from DSE import DSE_Calc, DVARS_Calc, CleanNIFTI

DVARSout = DVARS_Calc(fileOut,dd=1,WhichExpVal='median',WhichVar='hIQRd',scl=0.001, \
                demean=True,DeltapDvarThr=5)

vols2despike = DVARSout["Inference"]["H"]
vols2scrub = vols2despike

if dvars_despike == 'true':
    print("vols to despike: ",vols2despike)
    fdvars.write("\n vols to despike: "+ str(vols2despike))
    nvols2despike = vols2despike.shape[0]
    print("num vols to be despiked: ",nvols2despike)
    fdvars.write("\n vols to be despiked: "+ str(nvols2despike))
    despiking = np.zeros((nvols2despike,numTimePoints), dtype=int)  

    resid_DVARS = []
    ## Apply regresison again with spike regressors included
    if nvols2despike > 0:
        for s in range(nvols2despike):
            despiking[s,vols2despike[s]-1]=1

        regressors_despike = np.vstack((zRegressMat[r],despiking))

        rr = f_apply_reg(resting_vol,volBrain_vol,regressors_despike)
        
    resid_DVARS.append(rr)

    # save nifti image
    if len(zRegressMat)==1:
        fileOut = "/7_epi_%s_despiked.nii.gz" % nRc 
        matlabfilename = ''.join([NuisancePhysReg_out,'/volumes2scrub_',nRc,'_despiked.mat'])
    else:
        fileOut = "/7_epi_%s%d_despiked.nii.gz" % (nRc,pc)
        matlabfilename = ''.join([NuisancePhysReg_out,'/volumes2scrub_',nRc,pc,'_despiked.mat'])

    fileOut = ''.join([NuisancePhysReg_out,fileOut])
    print("Nifti file to be saved is: ",fileOut)

    # save new resting file
    resting_new = nib.Nifti1Image(rr.astype(np.float32),resting.affine,resting.header)
    nib.save(resting_new,fileOut) 

    print("savign MATLAB file ", matlabfilename)
    # mdic = {"resid" : rr, "vols2scrub":vols2scrub}
    mdic = {"vols2scrub":vols2scrub}
    savemat(matlabfilename, mdic)

    fdvars.close()

# THIS MAY NEED TO BE CHANGED TO RESTING NEW
if dvars_despike == 'true': 
    resid_before_despike = resid
    resid = resid_DVARS
    ## save data (for header info), regressors, and residuals
    fname = ''.join([NuisancePhysReg_out,'/NuisanceRegression_',nRc,'_despiked.npz'])
    np.savez(fname,resting_vol=resting_vol,volBrain_vol=volBrain_vol, \
    zRegressMat=zRegressMat,resid_before_despike=resid_before_despike,nR=nRc, \
    resid=resid, DVARS_Inference_Hprac=DVARSout["Inference"]["H"])
else:
    ## save residuals and regressor data
    fname = ''.join([NuisancePhysReg_out,'/NuisanceRegression_',nRc,'.npz'])
    np.savez(fname,resting_vol=resting_vol,volBrain_vol=volBrain_vol, \
    zRegressMat=zRegressMat,resid=resid,nR=nRc, \
    DVARS_Inference_Hprac=DVARSout["Inference"]["H"],vols2scrub=vols2scrub)

print("Saved residuals")

flog.close()
fqc.close()
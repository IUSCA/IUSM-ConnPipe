
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
lf = os.environ['logfile_name']
print("=== log file is ",lf," ===")
logfile_name = ''.join([lf,'.log'])
flog=open(logfile_name, "a+")

flog.write("\n *** python apply_reg **** ")
EPIpath=os.environ['EPIpath']
nuisanceReg=sys.argv[1]  #os.environ['nuisanceReg']
print("nuisanceReg is ",nuisanceReg)
flog.write("\n nuisanceReg "+ nuisanceReg)
config_param=int(sys.argv[2]) #int(os.environ['config_param'])
print("config_param is ",config_param)
flog.write("\n config_param "+ str(config_param))
numReg=int(os.environ['configs_EPI_numReg'])
flog.write("\n numReg "+ str(numReg))
print("numReg is ",numReg)
numGS=int(os.environ['configs_EPI_numGS'])
flog.write("\n numGS "+ str(numGS))
print("numGS is ",numGS)
physReg=sys.argv[3] #os.environ['physReg']
print("physReg is ",physReg)
flog.write("\n physReg "+ physReg)
PhReg_path = ''.join([EPIpath,'/',nuisanceReg,'/',physReg])
print("PhReg_path is ",PhReg_path)
flog.write("\n PhReg_path "+ PhReg_path )
nR=os.environ['nR']
flog.write("\n nR "+ nR)
print("nR is ",nR)
dvars_scrub=os.environ['flags_EPI_DVARS']
flog.write("\n dvars_scrub "+ dvars_scrub)
resting_file=os.environ['configs_EPI_resting_file']
flog.write("\n resting_file "+ resting_file)
resting_file = ''.join([EPIpath,resting_file]) 
flog.write("\n full resting file is "+ resting_file)
dctfMin=float(os.environ['configs_EPI_dctfMin'])
flog.write("\n dctfMin "+ str(dctfMin))


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
    fname = ''.join([PhReg_path,'/dataDCT.npz'])
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


if physReg == "aCompCorr":
    fname = ''.join([PhReg_path,'/dataPCA_WM-CSF.npz'])
    numphys = np.load(fname) 
    print("-- aCompCor PC of WM & CSF regressors")
    flog.write("\n -- aCompCor PC of WM & CSF regressors" )
    zRegressMat = [];

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

        components = np.vstack((regressors,\
                                csf,\
                                wm))

        print("components shape: ", components.shape)
        flog.write("\n components shape " + str(components.shape))
        zRegressMat.append(stats.zscore(components,axis=1));
        print("    -- PCA 1 through %d" % config_param)
        flog.write("\n    -- PCA 1 through " + str(config_param))

elif physReg == "PhysReg":
    fname = ''.join([PhReg_path,'/dataMnRg_WM-CSF.npz'])
    numphys = np.load(fname) 
    flog.write("\n numphys[CSFavg].shape " + str(numphys['CSFavg'].shape))
    flog.write("\n numphys[WMavg].shape " + str(numphys['WMavg'].shape))
    
    if config_param == 2:
        regressors = np.vstack((regressors,\
                                numphys['CSFavg'],\
                                numphys['WMavg']))
        print("   -- 2 physiological regressors ")
        flog.write("\n    -- 2 physiological regressors ")
        print("regressors shape ",regressors.shape)
        flog.write("\n regressors shape " + str(regressors.shape))
    if config_param == 4:
        regressors = np.vstack((regressors,\
                                numphys['CSFavg'],numphys['CSFderiv'],\
                                numphys['WMavg'],numphys['WMderiv']))        
        print("   -- 4 physiological regressors")
        flog.write("\n    -- 4 physiological regressors ")
        print("regressors shape ",regressors.shape)
        flog.write("\n regressors shape " + str(regressors.shape))
    if config_param == 8:
        regressors = np.vstack((regressors,\
                                numphys['CSFavg'],numphys['CSFavg_sq'],\
                                numphys['CSFderiv'],numphys['CSFderiv_sq'],\
                                numphys['WMavg'],numphys['WMavg_sq'],\
                                numphys['WMderiv'],numphys['WMderiv_sq'])) 
        print("   -- 8 physiological regressors ")   
        flog.write("\n    -- 8 physiological regressors ")
        print("regressors shape ",regressors.shape) 
        flog.write("\n regressors shape " + str(regressors.shape))
    
    zRegressMat = [];
    zRegressMat.append(stats.zscore(regressors,axis=1));


## regress-out motion/physilogical regressors 
print("2. Applying motion/physicological regression")
flog.write("\n 2. Applying motion/physicological regression")

# load resting vol
resting = nib.load(resting_file)
resting_vol = resting.get_data()
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape
print("resting_vol.shape ", sizeX,sizeY,sizeZ,numTimePoints)

# load GS mask
volBrain_file = ''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
volBrain = nib.load(volBrain_file)
volBrain_vol = volBrain.get_data()

for i in range(0,numTimePoints):
    rv = resting_vol[:,:,:,i]
    rv[volBrain_vol==0]=0
    resting_vol[:,:,:,i] = rv


resid = []
if dvars_scrub == 'true':
    resid_DVARS = []

for r in range(0,len(zRegressMat)):

    rr = f_apply_reg(resting_vol,volBrain_vol,zRegressMat[r])

    resid.append(rr)

    # save nifti image
    if len(zRegressMat)==1:
        fileOut = "/7_epi_%s.nii.gz" % nR 
        matlabfilename = ''.join([PhReg_path,'/NuisanceRegression_',nR,'.mat'])
    else:
        fileOut = "/7_epi_%s%d.nii.gz" % (nR,pc)
        matlabfilename = ''.join([PhReg_path,'/NuisanceRegression_',nR,pc,'.mat'])

    fileOut = ''.join([PhReg_path,fileOut])
    print("Nifti file to be saved is: ",fileOut)

    # save new resting file
    resting_new = nib.Nifti1Image(rr.astype(np.float32),resting.affine,resting.header)
    nib.save(resting_new,fileOut) 

    
    print("savign MATLAB file ", matlabfilename)
    mdic = {"resid" : rr,"resting_vol" : resting_vol}
    #savemat(matlabfilename, mdic)

    ## Calculate DVARS after regression

    if dvars_scrub == 'true':
        print("=== Calculating DVARS from residuals ===")
        configs_EPI_path2DVARS=os.environ['configs_EPI_path2DVARS']
        flog.write("\n configs_EPI_path2DVARS "+ str(configs_EPI_path2DVARS))
        print("configs_EPI_path2dvars ",configs_EPI_path2DVARS)

        import sys
        sys.path.append(configs_EPI_path2DVARS)
        from DSE import DSE_Calc, DVARS_Calc, CleanNIFTI

        DVARSout = DVARS_Calc(fileOut,dd=1,WhichExpVal='median',WhichVar='hIQRd',scl=0.001, \
                        demean=True,DeltapDvarThr=5)

        vols2scrub = DVARSout["Inference"]["H"]
        print("vols to scrub: ",vols2scrub)
        nvols2scrub = vols2scrub.shape[0]
        print("num vols to be scrubbed: ",nvols2scrub)
        scrubbing = np.zeros((nvols2scrub,numTimePoints), dtype=int)

        if nvols2scrub > 0:
            for s in range(nvols2scrub):
                scrubbing[s,vols2scrub[s]-1]=1

            regressors_scrub = np.vstack((zRegressMat[r],scrubbing))

            rr = f_apply_reg(resting_vol,volBrain_vol,regressors_scrub)
            
        resid_DVARS.append(rr)

        # save nifti image
        if len(zRegressMat)==1:
            fileOut = "/7_epi_%s_DVARS.nii.gz" % nR 
            matlabfilename = ''.join([PhReg_path,'/NuisanceRegression_',nR,'_DVARS.mat'])
        else:
            fileOut = "/7_epi_%s%d_DVARS.nii.gz" % (nR,pc)
            matlabfilename = ''.join([PhReg_path,'/NuisanceRegression_',nR,pc,'_DVARS.mat'])

        fileOut = ''.join([PhReg_path,fileOut])
        print("Nifti file to be saved is: ",fileOut)

        # save new resting file
        resting_new = nib.Nifti1Image(rr.astype(np.float32),resting.affine,resting.header)
        nib.save(resting_new,fileOut) 

        print("savign MATLAB file ", matlabfilename)
        mdic = {"resid" : rr}
        #savemat(matlabfilename, mdic)

if dvars_scrub == 'true': 
    resid_before_DVARS = resid
    resid = resid_DVARS
    ## save data (for header info), regressors, and residuals
    fname = ''.join([PhReg_path,'/NuisanceRegression_',nR,'_DVARS.npz'])
    np.savez(fname,resting_vol=resting_vol,volBrain_vol=volBrain_vol, \
    zRegressMat=zRegressMat,resid_before_DVARS=resid_before_DVARS,nR=nR, \
    resid=resid, DVARS_Inference_Hprac=DVARSout["Inference"]["H"])
else:
    ## save scrubbing data
    fname = ''.join([PhReg_path,'/NuisanceRegression_',nR,'.npz'])
    np.savez(fname,resting_vol=resting_vol,volBrain_vol=volBrain_vol, \
    zRegressMat=zRegressMat,resid=resid,nR=nR)


print("Saved residuals")

flog.close()

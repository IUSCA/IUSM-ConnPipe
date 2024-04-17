
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


print("\n *** python apply_reg **** ")
EPIpath=os.environ['EPIrun_out']

nuisanceReg=sys.argv[1]  
print("nuisanceReg is ",nuisanceReg)

physReg=sys.argv[2] 
print("physReg is ",physReg)
NuisancePhysReg_out = ''.join([EPIpath,'/',nuisanceReg,'/',physReg])
print("NuisancePhysReg_out is ",NuisancePhysReg_out)

configs_numHMP=int(os.environ['configs_EPI_numHMP'])
print("configs_numHMP is ",configs_numHMP)

configs_numPhys=int(os.environ['configs_EPI_numPhys'])
print("configs_numPhys is ",configs_numPhys)

numGS=int(os.environ['configs_EPI_numGS'])
print("numGS is ",numGS)

configs_FreqFilt=os.environ['configs_FreqFilt']
print("\n configs_FreqFilt ", configs_FreqFilt)

dvars_despike=os.environ['configs_EPI_despike']
print("\n dvars_despike "+ dvars_despike)

nR=os.environ['nR']
print("nR is ",nR)

# If BPF is set, need to crop nR, since BPF doesnt get done until after nuissance regressison.
if nR.endswith("_BPF"):
    nRc=nR[:-4]
else:
    nRc=nR

resting_file=os.environ['configs_EPI_resting_file']
print("\n resting_file ", resting_file)
resting_file = ''.join([EPIpath,resting_file]) 
print("\n full resting file is ", resting_file)


print("\n REGRESSORS -- Creating regressor matrix with the following:") 

# Nuisance regressors
if nuisanceReg == "AROMA":
    print("1. Using AROMA cleaned data")
    regressors = np.array([])

elif nuisanceReg == "HMPreg" or nuisanceReg == "AROMA_HMP":
    print("1. Applying Head Motion Param regressors") 

    if configs_numHMP == 24:
        print(" -- 24 Head motion regressors")
        fname=''.join([EPIpath,'/',nuisanceReg,'/motion12_regressors.npz'])
        m12reg = np.load(fname)
        print(sorted(m12reg.files))
        fname=''.join([EPIpath,'/',nuisanceReg,'/motion_sq_regressors.npz'])
        m_sq_reg = np.load(fname)  
        print(sorted(m_sq_reg.files))
        regressors = np.vstack((m12reg['motion'].T,m12reg['motion_deriv'].T,m_sq_reg['motion_sq'].T,m_sq_reg['motion_deriv_sq'].T))
    elif configs_numHMP == 12:
        print(" -- 12 Head motion regressors")
        fname=''.join([EPIpath,'/',nuisanceReg,'/motion12_regressors.npz'])
        m12reg = np.load(fname)
        print(sorted(m12reg.files))
        regressors = np.vstack((m12reg['motion'].T,m12reg['motion_deriv'].T))

print("\n regressors shape ",regressors.shape)

# physiological regressors
if physReg == "aCompCor":
    fname = ''.join([NuisancePhysReg_out,'/dataPCA',str(configs_numPhys),'_WM-CSF.npz'])
    numphys = np.load(fname) 
    print("-- aCompCor PC of WM & CSF regressors")

    if 0 < configs_numPhys < 6:
        print("-- Writing prespecified removal of %d components ----" % configs_numPhys)
        print("regressors shape ",regressors.shape)

        # Ensure that we have all CSF needed components
        print("numphys['CSFpca'] shape ",numphys['CSFpca'].shape)
        if numphys['CSFpca'].ndim == 2:
            csf = numphys['CSFpca'][:configs_numPhys,:]
            print("--- Using CSF PC number %d" % configs_numPhys)
        else:  # PCS failed and we used the mean signal and CSFpca is a singleton
            csf = numphys['CSFpca']
            print("--- Using CSF mean signal")
        print("csf shape ",csf.shape)

        # Ensure that we have all needed WM components
        print("numphys['WMpca'] shape ",numphys['WMpca'].shape)
        if numphys['WMpca'].ndim == 2:
            wm = numphys['WMpca'][:configs_numPhys,:]
            print("--- Using WM PC number %d" % configs_numPhys)
        else:  # WM PCA failed and we used the mean signal
            wm = numphys['WMpca']
            print("--- Using WM mean signal")

        print("wm shape ",wm.shape)

        if regressors.size:   #if we already filled regressors with HMP
             regressors = np.vstack((regressors,\
                                    csf,\
                                    wm))
        else:
            regressors = np.vstack((csf,\
                                    wm))

        print("regressors shape: ", regressors.shape)
        print("    -- PCA 1 through %d" % configs_numPhys)

elif physReg == "meanPhysReg":
    fname = ''.join([NuisancePhysReg_out,'/dataMnRg_WM-CSF.npz'])
    numphys = np.load(fname) 
    print("\n numphys[CSFavg].shape ", (numphys['CSFavg'].shape))
    print("\n numphys[WMavg].shape ", (numphys['WMavg'].shape))
    
    if configs_numPhys == 2:
        if regressors.size:
            regressors = np.vstack((regressors,\
                                numphys['CSFavg'],\
                                numphys['WMavg']))
        else:
            regressors = np.vstack((numphys['CSFavg'],\
                                numphys['WMavg']))  
        print("   -- 2 physiological regressors ")
        print("regressors shape ",regressors.shape)
    if configs_numPhys == 4:
        if regressors.size:
            regressors = np.vstack((regressors,\
                                numphys['CSFavg'],numphys['CSFderiv'],\
                                numphys['WMavg'],numphys['WMderiv'])) 
        else:
            regressors = np.vstack((numphys['CSFavg'],numphys['CSFderiv'],\
                                numphys['WMavg'],numphys['WMderiv']))       
        print("   -- 4 physiological regressors")
        print("regressors shape ",regressors.shape)
    if configs_numPhys == 8:
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
        print("regressors shape ",regressors.shape) 
    

# Global signal regression
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


# k DCT filtering
if configs_FreqFilt == "DCT":
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
    print("regressors shape ",regressors.shape)


# zscoring regressors
print("Z-scoring regressor matrix")
regressors = stats.zscore(regressors,axis=1)
print("regressors shape ",regressors.shape)

## regress-out motion/physilogical regressors 
print("2. Applying motion/physicological regression")

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

rr = f_apply_reg(resting_vol,volBrain_vol,regressors)

# save nifti image
fileOut = "/5_epi_%s.nii.gz" % nRc 

fileOut = ''.join([NuisancePhysReg_out,fileOut])
print("Nifti file to be saved is: ",fileOut)

# save new resting file
resting_new = nib.Nifti1Image(rr.astype(np.float32),resting.affine,resting.header)
nib.save(resting_new,fileOut) 

## Calculate DVARS after regression
print("=== Calculating DVARS from residuals ===")
configs_EPI_path2DVARS=os.environ['configs_EPI_path2DVARS']
print("configs_EPI_path2dvars ",configs_EPI_path2DVARS)

# Define file name where DVARS info will be printed
fname = ''.join([NuisancePhysReg_out,'/DVARS_',nRc,'.txt'])
fdvars=open(fname, "a+")

sys.path.append(configs_EPI_path2DVARS)
from DSE import DSE_Calc, DVARS_Calc, CleanNIFTI

DVARSout = DVARS_Calc(fileOut,dd=1,WhichExpVal='median',WhichVar='hIQRd',scl=0.001, \
                demean=True,DeltapDvarThr=5)

vols2despike = DVARSout["Inference"]["H"]

if dvars_despike == 'true':

    print("vols to despike: ",vols2despike)
    fdvars.write("\n vols to despike: "+ str(vols2despike))
    nvols2despike = vols2despike.shape[0]
    print("num vols to be despiked: ",nvols2despike)
    fdvars.write("\n vols to be despiked: "+ str(nvols2despike))
    despiking = np.zeros((nvols2despike,numTimePoints), dtype=int)  

    ## Apply regresison again with spike regressors included
    if nvols2despike > 0:
        for s in range(nvols2despike):
            despiking[s,vols2despike[s]-1]=1

        regressors_despike = np.vstack((regressors,despiking))

        rr_despike = f_apply_reg(resting_vol,volBrain_vol,regressors_despike)

    else:
        rr_despike = rr   
        print("WARNING: No volumes were despiked!") 

    fileOut = "/5_epi_%s_despiked.nii.gz" % nRc 
    matlabfilename = ''.join([NuisancePhysReg_out,'/volumes2scrub_',nRc,'_despiked.mat'])


    fileOut = ''.join([NuisancePhysReg_out,fileOut])
    print("Nifti file to be saved is: ",fileOut)

    # save new resting file
    resting_new = nib.Nifti1Image(rr_despike.astype(np.float32),resting.affine,resting.header)
    nib.save(resting_new,fileOut) 

    print("savign MATLAB file ", matlabfilename)
    mdic = {"vols2scrub":vols2despike}
    savemat(matlabfilename, mdic)

    fdvars.close()



## save non-despiked and despiked data in npz format for further analysis
fname = ''.join([NuisancePhysReg_out,'/NuisanceRegression_',nRc,'.npz'])

if dvars_despike == 'true':
    print("apply_reg: saving despiked regressors in file"+fname)
    np.savez(fname, nR=nRc, \
    regressors=regressors,despiking=despiking, \
    resid=rr,resid_despike=rr_despike, \
    DVARS_Inference_Hprac=DVARSout["Inference"]["H"], \
    vols2scrub=vols2despike)
else:
    print("apply_reg: saving despiked regressors in file"+fname)
    np.savez(fname,nR=nRc, \
    regressors=regressors,resid=rr, \
    DVARS_Inference_Hprac=DVARSout["Inference"]["H"], \
    vols2scrub=vols2despike)


print("Saved residuals")

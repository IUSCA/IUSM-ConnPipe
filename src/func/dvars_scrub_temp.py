
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

print("\n *** python dvars-based scrubbbing **** ")
EPIpath=os.environ['EPIrun_out']
nuisanceReg=sys.argv[1]  
print("nuisanceReg is ",nuisanceReg)
physReg=sys.argv[2] 
print("physReg is ",physReg)
NuisancePhysReg_out = ''.join([EPIpath,'/',nuisanceReg,'/',physReg])
print("NuisancePhysReg_out is ",NuisancePhysReg_out)

nR=os.environ['nR']
print("nR is ",nR)
dvars_scrub=os.environ['configs_EPI_DVARS']
print("dvars_scrub ", dvars_scrub)

resting_file=os.environ['configs_EPI_resting_file']
print("resting_file "+ resting_file)
resting_file = ''.join([EPIpath,resting_file]) 
print("full resting file is "+ resting_file)


resting = nib.load(resting_file)

fname = ''.join([NuisancePhysReg_out,'/NuisanceRegression_',nR,'.npz'])

print("\n REGRESSORS -- Loading regressor matrix:") 
print("Loading regressor matrix:") 
print(fname)

resid_data=np.load(fname)

# load resting vol
resting_vol = resid_data['resting_vol']
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape

# load GS mask
volBrain_vol = resid_data['volBrain_vol']

# regressor matrix
zRegressMat = resid_data['zRegressMat']

# residuals prior to DVARS scrub
resid_before_DVARS = resid_data['resid']


if dvars_scrub == 'true':
    resid = []

## Calculate DVARS after regression
    for r in range(0,len(zRegressMat)):

        print("=== Calculating DVARS from residuals ===")
        configs_EPI_path2DVARS=os.environ['configs_EPI_path2DVARS']
        print("configs_EPI_path2dvars ",configs_EPI_path2DVARS)

        # Define file name where DVARS info will be printed
        fname = ''.join([NuisancePhysReg_out,'/DVARS_',nR,'.txt'])
        fdvars=open(fname, "a+")

        import sys
        sys.path.append(configs_EPI_path2DVARS)
        from DSE import DSE_Calc, DVARS_Calc, CleanNIFTI

        if len(zRegressMat)==1:
            fileOut = "/5_epi_%s.nii.gz" % nR 
        else:
            fileOut = "/5_epi_%s%d.nii.gz" % (nR,pc)

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
            
        resid.append(rr)

        # save nifti image
        if len(zRegressMat)==1:
            fileOut = "/5_epi_%s_DVARS.nii.gz" % nR 
            matlabfilename = ''.join([NuisancePhysReg_out,'/volumes2scrub_',nR,'_DVARS.mat'])
        else:
            fileOut = "/5_epi_%s%d_DVARS.nii.gz" % (nR,pc)
            matlabfilename = ''.join([NuisancePhysReg_out,'/volumes2scrub_',nR,pc,'_DVARS.mat'])

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


    ## save data (for header info), regressors, and residuals
    fname = ''.join([NuisancePhysReg_out,'/NuisanceRegression_',nR,'_DVARS.npz'])
    np.savez(fname,resting_vol=resting_vol,volBrain_vol=volBrain_vol, \
    zRegressMat=zRegressMat,resid_before_DVARS=resid_before_DVARS,nR=nR, \
    resid=resid, DVARS_Inference_Hprac=DVARSout["Inference"]["H"])

    print("Saved residuals")

elif dvars_scrub == 'false':

    print("=== Scrubbing with FSL's FD and DVARS ===")
    




flog.close()
fqc.close()

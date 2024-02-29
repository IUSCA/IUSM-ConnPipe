
############################################################################### 

import os
import sys
import numpy as np
from scipy.io import savemat

EPIpath=sys.argv[1]
print(EPIpath)

numTimePoints=int(sys.argv[2])
print(numTimePoints)

QCfile_name=os.environ['QCfile_name']
QCfile_name = ''.join([QCfile_name,'.log'])
print("QCfile_name: ",QCfile_name)
f=open(QCfile_name, "a+")

## FD
file_fd=''.join([EPIpath,'/motionRegressor_fd.txt'])
if os.path.exists(file_fd):
    fd = np.loadtxt(file_fd)
    print("file_fd dimensions: ",fd.ndim )
    if fd.ndim > 1:
        fd_scrub = np.sum(fd,axis=1)
    elif fd.ndim == 1:
        fd_scrub = fd
else:
    print("file_fd not generated; using dummy vector of zeros")
    f.write( "\n %s file not generated \n" % file_fd)
    fd_scrub = np.zeros(numTimePoints)  

n_fd_outliers = np.count_nonzero(fd_scrub)
print("number of fd_outliers: ", n_fd_outliers)
f.write( "\n number of fd_outliers: %d \n" % n_fd_outliers)

# compute mean and std of motionMetric
file_fd=''.join([EPIpath,'/motionMetric_fd.txt'])
if os.path.exists(file_fd):
    fd = np.loadtxt(file_fd)
    fd_mean = np.mean(fd,axis=0)
    fd_std = np.std(fd,axis=0)
    fd_min = np.amin(fd,axis=0)
    fd_max = np.amax(fd,axis=0)
    f.write( "\n motionMatric_fd stats: \n ")
    f.write( "Mean = %f \n" % fd_mean)
    f.write( "Std = %f \n" % fd_std)
    f.write( "Min = %f \n" % fd_min)
    f.write( "Max = %f \n" % fd_max)


## DVARS
file_dvars=''.join([EPIpath,'/motionRegressor_dvars.txt'])
if os.path.exists(file_dvars):
    dvar = np.loadtxt(file_dvars)
    print("file_dvars dimensions: ",dvar.ndim )
    if dvar.ndim > 1:
        dvars_scrub = np.sum(dvar,axis=1)
    elif dvar.ndim == 1:
        dvars_scrub = dvar
else:
    print("file_dvars not generated; using dummy vector of zeros")
    dvars_scrub = np.zeros(numTimePoints)
n_dvars_outliers = np.count_nonzero(dvars_scrub)
print("number of dvars_outliers: ", n_dvars_outliers)
f.write( "\n number of dvars_outliers: %d \n" % n_dvars_outliers)


# compute mean and std of motionMetric
file_dvar=''.join([EPIpath,'/motionMetric_dvars.txt'])
if os.path.exists(file_dvar):
    dvar = np.loadtxt(file_dvar)
    dvar_mean = np.mean(dvar,axis=0)
    dvar_std = np.std(dvar,axis=0)
    dvar_min = np.amin(dvar,axis=0)
    dvar_max = np.amax(dvar,axis=0)
    f.write( "\n motionMatric_dvar stats: \n ")
    f.write( "Mean = %f \n" % dvar_mean)
    f.write( "Std = %f \n" % dvar_std)
    f.write( "Min = %f \n" % dvar_min)
    f.write( "Max = %f \n" % dvar_max)

scrub = np.add(fd_scrub,dvars_scrub)
good_vols = scrub == 0
good_vols = good_vols.astype(bool).astype(int)
print("number of good vols: ",np.count_nonzero(good_vols))
f.write( "\n number of good vols: %d \n" % np.count_nonzero(good_vols))
print("number of outliers to be scrubbed from dataset: ",np.count_nonzero(scrub))
f.write( "\n number of outliers to be scrubbed from dataset: %d \n" % np.count_nonzero(scrub))

f.close()

fname=''.join([EPIpath,'/scrubbing_goodvols.npz'])
np.savez(fname, good_vols=good_vols)

fname=''.join([EPIpath,'/scrubbing_goodvols.mat'])
print("savign MATLAB file ", fname)
mdic = {"good_vols": good_vols}
savemat(fname, mdic)
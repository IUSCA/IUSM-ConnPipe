

############################################################################### 

function f_get_motion_outliers() {
path="$1" numTimePoints="$2" python - <<END
import os
import numpy as np
from scipy.io import savemat

EPIpath=os.environ['path']
print(EPIpath)

numTimePoints=int(os.environ['numTimePoints'])
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

END
}

##############################################################################
source ${EXEDIR}/src/func/bash_funcs.sh

EPIpath=$1
fIn=$2
numTimePoints=$3

echo "EPIpath is -- ${EPIpath}"
echo "fIn is -- ${fIn}"
echo "numTimePoints is -- ${numTimePoints}"

# ------------------------------------------------------------------------- #
## Frame Displacement regressor
echo "# Computing DF regressor"

fileOut1="${EPIpath}/motionRegressor_fd.txt"
fileMetric="${EPIpath}/motionMetric_fd.txt"
filePlot="${EPIpath}/motionPlot_fd.png"

if [[ -e ${fileOut1} ]]; then
    cmd="rm ${fileOut1}"
    log $cmd 
    eval $cmd 
fi

if [[ -e ${fileMetric} ]]; then
    cmd="rm ${fileMetric}"
    log $cmd 
    eval $cmd 
fi

if [ -z ${configs_EPI_FDcut+x} ]; then  # if the variable ${configs_EPI_FDcut} is unset

    echo "fsl_motion_outliers - Will use box-plot cutoff = P75 + 1.5 x IQR"

    cmd="fsl_motion_outliers -i ${fIn} \
        -o ${fileOut1} \
        -s ${fileMetric} \
        -p ${filePlot} \
        --fd"

else   # if the variable ${configs_EPI_FDcut} exists and is different from empty 
    
    echo " configs_EPI_FDcut is set to ${configs_EPI_FDcut}"

   cmd="fsl_motion_outliers -i ${fIn} \
    -o ${fileOut1} \
    -s ${fileMetric} \
    -p ${filePlot} \
    --fd --thresh=${configs_EPI_FDcut}" 

fi 

log $cmd
eval $cmd 
out=$?

if [[ ! $out -eq 0 ]]; then
    echo "FD exit code"
    echo "$out"
fi

# ------------------------------------------------------------------------- #
## DVARS

echo "# Computing DVARS regressors"

fileOut="${EPIpath}/motionRegressor_dvars.txt"
fileMetric="${EPIpath}/motionMetric_dvars.txt"
filePlot="${EPIpath}/motionPlot_dvars.png"

if [[ -e ${fileMetric} ]]; then
    cmd="rm ${fileMetric}"
    log $cmd 
    eval $cmd 
fi

if [ -z ${configs_EPI_DVARScut+x} ]; then

    log "fsl_motion_outliers - Will use box-plot cutoff = P75 + 1.5 x IQR"

    cmd="fsl_motion_outliers -i ${fIn} \
        -o ${fileOut} \
        -s ${fileMetric} \
        -p ${filePlot} \
        --dvars"

else
    
    echo " configs_EPI_DVARScut is set to ${configs_EPI_DVARScut}"

   cmd="fsl_motion_outliers -i ${fIn} \
    -o ${fileOut} \
    -s ${fileMetric} \
    -p ${filePlot} \
    --dvars --thresh=${configs_EPI_DVARScut}" 

fi 

log $cmd
eval $cmd 
out=$?

if [[ ! $out -eq 0 ]]; then
    log "Dvars exit code"
    log "$out"
fi


log "calling f_get_motion_outliers:"
cmd="f_get_motion_outliers ${EPIpath} ${numTimePoints}"
log $cmd
eval $cmd

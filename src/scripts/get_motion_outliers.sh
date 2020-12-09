

############################################################################### 

function f_load_motion_reg() {
path="$1" numTimePoints="$2" python - <<END
import os
import numpy as np
from scipy.io import savemat

EPIpath=os.environ['path']
print(EPIpath)

numTimePoints=int(os.environ['numTimePoints'])
print(numTimePoints)

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

scrub = np.add(fd_scrub,dvars_scrub)
scrub = scrub == 0
scrub = scrub.astype(bool).astype(int)
#print(scrub)
print("number of good vols: ",np.count_nonzero(scrub))

fname=''.join([EPIpath,'/scrubbing_goodvols.npz'])
np.savez(fname, scrub=scrub)

fname=''.join([EPIpath,'/scrubbing_goodvols.mat'])
print("savign MATLAB file ", fname)
mdic = {"scrub": scrub}
savemat(fname, mdic)

END
}

##############################################################################
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
    echo $cmd 
    eval $cmd 
fi

if [[ -e ${fileMetric} ]]; then
    cmd="rm ${fileMetric}"
    echo $cmd 
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

echo $cmd
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
    echo $cmd 
    eval $cmd 
fi

if [ -z ${configs_EPI_DVARScut+x} ]; then

    echo "fsl_motion_outliers - Will use box-plot cutoff = P75 + 1.5 x IQR"

    cmd="fsl_motion_outliers -i ${fIn} \
        -o ${fileOut} \
        -s ${fileMetric} \
        -p ${filePlot} \
        --dvars"

else
    
    echo " configs_EPI_FDcut is set to ${configs_EPI_DVARScut}"

   cmd="fsl_motion_outliers -i ${fIn} \
    -o ${fileOut} \
    -s ${fileMetric} \
    -p ${filePlot} \
    --dvars --thresh=${configs_EPI_DVARScut}" 

fi 

echo $cmd
eval $cmd 
out=$?

if [[ ! $out -eq 0 ]]; then
    echo "Dvars exit code"
    echo "$out"
fi


echo "calling f_load_motion_reg:"
f_load_motion_reg ${EPIpath} ${numTimePoints}

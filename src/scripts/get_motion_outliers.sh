

############################################################################### 

function f_load_motion_reg() {
path="$1" ${python3_7} - <<END
import os
import numpy as np

EPIpath=os.environ['path']
print(EPIpath)

## FD
file_fd=''.join([EPIpath,'/motionRegressor_fd.txt'])
fd_scrub = np.sum(np.loadtxt(file_fd),axis=1)
n_fd_outliers = np.count_nonzero(fd_scrub)
print("number of fd_outliers: ", n_fd_outliers)

## DVARS
file_dvars=''.join([EPIpath,'/motionRegressor_dvars.txt'])
dvars_scrub = np.sum(np.loadtxt(file_dvars),axis=1)
n_dvars_outliers = np.count_nonzero(dvars_scrub)
print("number of dvars_outliers: ", n_dvars_outliers)

scrub = np.add(fd_scrub,dvars_scrub)
scrub = scrub == 0
scrub = scrub.astype(bool).astype(int)
#print(scrub)
print("number of good vols: ",np.count_nonzero(scrub))


# fname=''.join([EPIpath,'/scrubbing_goodvols.mat'])
# np.savetxt(fname, scrub,fmt='%d')

fname=''.join([EPIpath,'/scrubbing_goodvols.npz'])
np.savez(fname, scrub=scrub)


END
}

##############################################################################
EPIpath=$1
fIn=$2

echo "EPIpath is -- ${EPIpath}"
echo "fIn is -- ${fIn}"

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

if [[ -e ${fileMetric} ]] && [[ -e ${fileOut1} ]]; then
    echo "calling f_load_motion_reg:"
    f_load_motion_reg ${EPIpath}
else
    echo "WARNING File ${fileMetric} and/or ${fileOut1} not found!"
    exit 1
fi

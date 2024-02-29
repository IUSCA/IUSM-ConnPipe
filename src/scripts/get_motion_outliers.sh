#!/bin/bash
#
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
echo "fsl_motion_outliers - Will use box-plot cutoff = P75 + 1.5 x IQR"
echo "# Computing Frame Displacement regressor"

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

cmd="fsl_motion_outliers -i ${fIn} \
    -o ${fileOut1} \
    -s ${fileMetric} \
    -p ${filePlot} \
    --fd"

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

cmd="fsl_motion_outliers -i ${fIn} \
    -o ${fileOut} \
    -s ${fileMetric} \
    -p ${filePlot} \
    --nomoco --dvars"

log $cmd
eval $cmd 
out=$?

if [[ ! $out -eq 0 ]]; then
    log "DVARS exit code"
    log "$out"
fi

log "calling python script get_motion_outliers:"
cmd="python ${EXEDIR}/src/func/get_motion_outliers.py ${EPIpath} ${numTimePoints}"
log --no-datetime $cmd
eval $cmd
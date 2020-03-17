
#!/bin/bash
#
# Script: f_preproc_DWI.m adaptaion from Matlab script 
#

###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

############################################################################### 

############################################################################### 


echo "=================================="
echo "2. Fitting Diffusion Tensor"
echo "=================================="

# set paths to opposite phase encoded images
path_DWI_UNWARP=${DWIpath}/${configs_unwarpFolder}

path_DWI_EDDY="${DWIpath}/EDDY"

if [[ ! -d "${path_DWI_EDDY}" ]]; then
    cmd="mkdir ${path_DWI_EDDY}"
    log $cmd
    eval $cmd
fi 


# remove any existing files
rm -rf ${path_DWI_EDDY}/*
log "rm -rf ${path_DWI_EDDY}/*"
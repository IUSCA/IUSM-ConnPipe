
#!/bin/bash
#
# Script: DWI_A adaptaion from Matlab script 
#

###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

###############################################################################

function read_bvals_bvecs() {
path="$1" python - <<END
import os
from dipy.io import read_bvals_bvecs
import nibabel as nib
import numpy as np

p=os.environ['path']
# p='/N/dc2/scratch/aiavenak/testdata/10692_1_AAK/DWI'

pbval=''.join([p,'/0_DWI.bval'])
pbvec=''.join([p,'/0_DWI.bvec'])

bvals, bvecs = read_bvals_bvecs(pbval,pbvec)
# print("bvals size", bvals.shape)
# print("bvecs size", bvecs.shape)

if bvals.shape[0] > 1:
    # vector is horizontal, needs to be transposed
    bvals = bvals.reshape((1,bvals.size)) 
    # print("bvals size", bvals.shape)

if bvecs.shape[0] > 3:
    # vector is horizontal, needs to be transposed
    bvecs = bvecs.T 
    # print("bvecs size", bvecs.shape)

DWIp=''.join([p,'/0_DWI.nii.gz'])
DWI=nib.load(DWIp)  

# print('bvals.shape[1] ',bvals.shape[1])
# print('bvecs.shape[1] ',bvecs.shape[1])
# print('DWI.shape[3] ',DWI.shape[3])

if bvals.shape[1] == DWI.shape[3] and bvecs.shape[1] == DWI.shape[3]:
    np.savetxt(pbval,bvals,delimiter='\n',fmt='%u')
    np.savetxt(pbvec,bvecs.T,delimiter='\t',fmt='%f')
    print('1')
else:
    print('0')

END
}

###############################################################################

if [[ -d ${DWIpath} ]]; then

    log "DWI_B processing for subject ${SUBJ}"

    path_DWI_EDDY="${DWIpath}/EDDY"
    path_DWI_DTIfit="${DWIpath}/DTIfit"

    if [[ ! -d "${path_DWI_EDDY}" ]]; then
        log "Path to EDDY directory does not exist. Exiting..."
        exit 1
    else 
        if [[ ! -d "${path_DWI_DTIfit}" ]]; then
            log "Path to DTIfit directory does not exist. Exiting..."
            exit 1
        fi
    fi

    #### Registration of B0 to T1
    if ${flags_DWI_regT1_2DWI}; then

        cmd="${EXEDIR}/src/scripts/DWI_B_regT12DWI.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at DWI_B_regT12DWI. exiting."
            exit 1
        fi  
    fi

    #### MRtrix
    if ${flags_DWI_MRtrix}; then

        cmd="${EXEDIR}/src/scripts/DWI_B_MRtrix.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at DWI_B_MRtrix. exiting."
            exit 1
        fi  
    fi

    #### Connectivity Matrix
    if ${flags_DWI_connMatrix}; then

        cmd="${EXEDIR}/src/scripts/DWI_B_connMatrix.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at DWI_B_connMatrix. exiting."
            exit 1
        fi  
    fi

else 

    log "WARNING Subject DWI directory does not exist; skipping DWI processing for subject ${SUBJ}"

fi 

#!/bin/bash
#
# Script: fMRI_A adaptaion from Matlab script 
#

###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

############################################################################### 

function f_load_motion_reg() {
path="$1" numReg="$2" python - <<END
import os
import numpy as np
from scipy.io import savemat

EPIpath=os.environ['path']

numReg=int(os.environ['numReg'])

# load motion regressors
fname=''.join([EPIpath,'/motion.txt'])
motion = np.loadtxt(fname)
[rows,columns] = motion.shape

# derivatives of 6 motion regressors
motion_deriv = np.zeros((rows,columns))

for i in range(columns):
    m = motion[:,i]
    m_deriv = np.diff(m)
    motion_deriv[1:,i] = m_deriv

## save the data
# fname=''.join([EPIpath,'/HMPreg/motion_deriv.txt'])
# np.savetxt(fname, motion_deriv,fmt='%2.7f')
# fname=''.join([EPIpath,'/HMPreg/motion.txt'])
# np.savetxt(fname, motion,fmt='%2.7f')
fname=''.join([EPIpath,'/HMPreg/motion12_regressors.npz'])
np.savez(fname,motion_deriv=motion_deriv,motion=motion)
fname=''.join([EPIpath,'/HMPreg/motion12_regressors.mat'])
print("savign MATLAB file ", fname)
mdic = {"motion_deriv": motion_deriv,"motion": motion}
savemat(fname, mdic)

if numReg == 24:
    motion_sq = np.power(motion,2)
    motion_deriv_sq = np.power(motion_deriv,2)


# fname=''.join([EPIpath,'/HMPreg/motion_sq.txt'])
# np.savetxt(fname, motion_sq,fmt='%2.7f')
# fname=''.join([EPIpath,'/HMPreg/motion_deriv_sq.txt'])
# np.savetxt(fname, motion_deriv_sq,fmt='%2.7f')
fname=''.join([EPIpath,'/HMPreg/motion_sq_regressors.npz'])
np.savez(fname,motion_sq=motion_sq,motion_deriv_sq=motion_deriv_sq)
fname=''.join([EPIpath,'/HMPreg/motion_sq_regressors.mat'])
print("savign MATLAB file ", fname)
mdic = {"motion_sq": motion_sq, "motion_deriv_sq": motion_deriv_sq}
savemat(fname, mdic)

END
}

##############################################################################

echo "# =========================================================="
echo "# 5.1 Head Motion Parameter Regression. "
echo "# =========================================================="

if [[ ! -e "${EPIpath}/4_epi.nii.gz" ]]; then  

    log "WARNING -  ${EPIpath}/4_epi.nii.gz does not exist. Skipping further analysis..."
    exit 1        

else

    HMPpath="${EPIpath}/HMPreg"
    if [[ ! -d ${HMPpath} ]]; then
        cmd="mkdir ${HMPpath}"
        log $cmd
        eval $cmd 
    fi

    # load 6 motion regressors and get derivatives
    f_load_motion_reg ${EPIpath} ${configs_EPI_numReg}
    if [ $? -eq 0 ]; then
        log "Saved motion regressors and temporal derivatives"
        log "Saved quadratics of motion and its derivatives"
    else
        log "WARNING motion regressors and derivatives not saved. Exiting."
    fi

fi 
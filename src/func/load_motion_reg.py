
import os
import sys
import numpy as np
from scipy.io import savemat

EPIpath=os.environ['EPIrun_out']

HMPpath=sys.argv[1]
numReg=int(sys.argv[2])


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


fname=''.join([HMPpath,'/motion12_regressors.npz'])
np.savez(fname,motion_deriv=motion_deriv,motion=motion)
fname=''.join([HMPpath,'/motion12_regressors.mat'])
print("savign MATLAB file ", fname)
mdic = {"motion_deriv": motion_deriv,"motion": motion}
savemat(fname, mdic)

if numReg == 24:
    motion_sq = np.power(motion,2)
    motion_deriv_sq = np.power(motion_deriv,2)

    fname=''.join([HMPpath,'/motion_sq_regressors.npz'])
    np.savez(fname,motion_sq=motion_sq,motion_deriv_sq=motion_deriv_sq)
    fname=''.join([HMPpath,'/motion_sq_regressors.mat'])
    print("savign MATLAB file ", fname)
    mdic = {"motion_sq": motion_sq, "motion_deriv_sq": motion_deriv_sq}
    savemat(fname, mdic)


## save the data
# fname=''.join([EPIpath,'/HMPreg/motion_deriv.txt'])
# np.savetxt(fname, motion_deriv,fmt='%2.7f')
# fname=''.join([EPIpath,'/HMPreg/motion.txt'])
# np.savetxt(fname, motion,fmt='%2.7f')
import os
import sys
#from dipy.io import read_bvals_bvecs
from dipy import read_bvals_bvecs
import nibabel as nib
import numpy as np

p=sys.argv[4]
fileBval=sys.argv[1]
# print("fileBval is ",fileBval)
fileBvec=sys.argv[2]
# print("fileBvec is ",fileBvec)
fileNifti=sys.argv[3]
# print("fileNifti is ",fileNifti)

if len(sys.argv) > 5:
    postfix=sys.argv[5]
    pbval = ''.join([p,'/0_DWI_',postfix,'.bval'])
    pbvec = ''.join([p,'/0_DWI_',postfix,'.bvec'])
else:
    pbval = ''.join([p,'/0_DWI.bval'])
    pbvec = ''.join([p,'/0_DWI.bvec'])

bvals, bvecs = read_bvals_bvecs(fileBval,fileBvec)
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

#DWIp=''.join([p,'/',fileNifti,'.gz'])
DWI=nib.load(fileNifti)  

# print('bvals.shape[1] ',bvals.shape[1])
# print('bvecs.shape[1] ',bvecs.shape[1])
# print('DWI.shape[3] ',DWI.shape[3])

if bvals.shape[1] == DWI.shape[3] and bvecs.shape[1] == DWI.shape[3]:
    np.savetxt(pbval,bvals,delimiter='\n',fmt='%u')
    np.savetxt(pbvec,bvecs.T,delimiter='\t',fmt='%f')
    print('1')
else:
    print('0')

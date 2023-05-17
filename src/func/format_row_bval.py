
import os
import sys
from dipy.io import read_bvals_bvecs
import nibabel as nib
import numpy as np

DTIfit=sys.argv[1]
print("DTIfit ",DTIfit)
dwifile=sys.argv[2]
print("dwifile ",dwifile)
DWIpath=os.environ['DWIpath']
print("DWIpath ",DWIpath)

pbval=''.join([dwifile,'.bval'])
print('pbval',pbval)
pbvec=''.join([dwifile,'.bvec'])
print('pbvec',pbvec)

bvals, bvecs = read_bvals_bvecs(pbval,pbvec)
 
bvals = bvals.reshape((bvals.size,1))

pbval_row=''.join([DTIfit,'/3_DWI.bval'])

np.savetxt(pbval_row,bvals.T,delimiter='\t',fmt='%u')

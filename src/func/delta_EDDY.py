import sys
import os
import nibabel as nib
import numpy as np

path_DWI_EDDY=os.environ['EDDYpath']
print('path_DWI_EDDY',path_DWI_EDDY)
DWIpath=os.environ['DWIpath']
print('DWIpath',DWIpath)
fileOut=sys.argv[1]
print('fileOut',fileOut)
dwifile=sys.argv[2]
print('dwifile',dwifile)

#fname=''.join([DWIpath,'/',dwifile,'.nii.gz'])
print('DWI file is:', dwifile)
DWI=nib.load(dwifile)  
DWI_vol = np.asanyarray(DWI.dataobj)

fname=''.join([fileOut,'.nii.gz'])
print('corrDWI file is:', fname)
corrDWI=nib.load(fname)
corrDWI_vol = np.asanyarray(corrDWI.dataobj)

corrDWI_vol = corrDWI_vol - DWI_vol

deltaEddy = ''.join([path_DWI_EDDY,'/delta_DWI.nii.gz'])
corrDWI_new = nib.Nifti1Image(corrDWI_vol.astype(np.float32),corrDWI.affine,corrDWI.header)
nib.save(corrDWI_new,deltaEddy)

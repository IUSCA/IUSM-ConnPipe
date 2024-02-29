
import os
import numpy as np
import nibabel as nib

EPIpath=os.environ['EPIrun_out']

# read brain mask
fname = ''.join([EPIpath,'/rT1_brain_mask.nii.gz'])
volBrain = nib.load(fname)
volBrain_vol = np.asanyarray(volBrain.dataobj)

fname = ''.join([EPIpath,'/2_epi_meanvol_mask.nii.gz'])
volRef = nib.load(fname)
volRef_vol = np.asanyarray(volRef.dataobj)

volBrain_vol = (volBrain_vol>0) & (volRef_vol != 0)
fileOut=''.join([EPIpath,'/rT1_brain_mask_FC.nii.gz'])
volBrain_new = nib.Nifti1Image(volBrain_vol.astype(np.float32),volBrain.affine,volBrain.header)
nib.save(volBrain_new,fileOut)  

print("------- End of read_physiol_data.py -----")

import os
import sys
import nibabel as nib
import numpy as np

DWIpath=os.environ['DWIpath']
dwifile=sys.argv[1]
path_DWI_EDDY=os.environ['path_DWI_EDDY']

# read in DWI data and find number of volumes
#fname=''.join([DWIpath,'/',dwifile,'.nii.gz'])
DWI=nib.load(dwifile)  
ss=DWI.shape
numVols=ss[3];

b0file = ''.join([DWIpath,"/b0file.txt"])

ff = open(b0file,"r")
ffl = ff.readlines()

Index=np.ones((numVols,1),dtype=np.int64)

# Preserve temporal information about B0 location
for i in range(0,len(ffl)):
    ii = int(ffl[i]) 
    if ii != 1:  
        #  for every subsequent B0 the volume index increases. 
        # This provides temporal information about location of B0 volumes
        Index[ii:]=i+1


# save to file
fname=''.join([path_DWI_EDDY,'/index.txt'])
np.savetxt(fname,Index, fmt='%s')

ff.close()

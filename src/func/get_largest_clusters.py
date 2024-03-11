
############################################################################### 

#import os.path
import os
import sys
import numpy as np
import nibabel as nib
from skimage import measure 

print(" ********* GET LARGES CLUSTERS ********* ")
print("PYTHON VERSION ",sys.version)

EPIpath=os.environ['EPIpath']
print("EPIpath is: ",EPIpath)

fIn=sys.argv[1]
print("fIN: ", fIn)

fOut=sys.argv[2]
print("fOut: ", fOut)

thr=int(sys.argv[3])
print("thr: ", thr)


fileIn=''.join([EPIpath,fIn])
fileOut=''.join([EPIpath,fOut])

v=nib.load(fileIn)  
v_vol=v.get_fdata()
# print(v_vol.shape)
N = int(np.max(v_vol))
# print("N = ",N)
vol_clean = np.zeros(v_vol.shape)

for i in range(1,N+1):
    # print(i)
    vi = v_vol == i
    vi = vi.astype(bool).astype(int)
    # print("number of non-zero elements",np.count_nonzero(vi))
    clusters = measure.label(vi,connectivity=2,return_num=True)
    # print("number of clusters ",clusters[1])
    for j in range(1,clusters[1]+1):
        vj = np.count_nonzero(clusters[0] == j)
        # print("label ",j, "num elements ",vj)
        if vj > thr:
            # print("nonzero elements in vol_clean :",np.count_nonzero(vol_clean))
            vol_clean[clusters[0] == j] = i
            # print("nonzero elements in vol_clean :",np.count_nonzero(vol_clean))



v_vol_new = nib.Nifti1Image(v_vol.astype(np.float32),v.affine,v.header)
nib.save(v_vol_new,fileOut) 
print("get_largest_clusters: saved ",fileOut)

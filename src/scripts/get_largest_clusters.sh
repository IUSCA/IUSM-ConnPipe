

############################################################################### 

function largest_clusters() {
path="$1" fIn="$2" fOut="$3" thr="$4"  python - <<END
import os.path
import numpy as np
import nibabel as nib
from skimage import measure 

EPIpath=os.environ['path']
# print(EPIpath)

fIn=os.environ['fIn']
# print("fIN: ", fIn)

fOut=os.environ['fOut']
# print("fOut: ", fOut)

thr=int(os.environ['thr'])
# print("thr: ", thr)


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
    clusters = measure.label(vi,neighbors=8,return_num=True)
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


END
}

##############################################################################
EPIpath=$1
fileIn=$2
fileOut=$3
threshold=$4

echo "EPIpath is -- ${EPIpath}"
echo "FileIn is -- ${fileIn}"
echo "fileOut is -- ${fileOut}"
echo "threshold is -- ${threshold}"


#echo "Calling Python script 
echo "calling pyhon script largest_clusters"
largest_clusters ${EPIpath} ${fileIn} ${fileOut} ${threshold}



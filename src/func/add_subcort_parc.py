
import os.path
import sys 
import numpy as np
import nibabel as nib

print("------ Start Python script --------- ")

parcpath=sys.argv[1]
print("parcpath is: ",parcpath)

pnodal=int(sys.argv[2])
print("pnodal is: ",pnodal)
print(type(pnodal))

file_Subcort=sys.argv[3]
print("file_Subcort is: ",file_Subcort)

subcortUser=os.environ['configs_T1_subcortUser']
print("subcortUser is: ",subcortUser)
print(type(subcortUser))

# head_tail = os.path.split(parcpath)

# print(head_tail[0])
# print(head_tail[1])

# fileSubcort = ''.join([head_tail[0],'/T1_subcort_seg.nii.gz'])
# print(fileSubcort)

parc = nib.load(parcpath)
parc_vol = parc.get_data()
#print(parc_vol.shape)
MaxID = np.max(parc_vol)
#print(MaxID)

subcort = nib.load(file_Subcort)
subcort_vol = subcort.get_data()
#ind = np.argwhere(subcort_vol == 16)
#print(ind)

if subcortUser == "false":  # FSL-provided subcortical
    subcort_vol[subcort_vol == 16] = 0
    #ind = np.argwhere(subcort_vol == 16)
    #print(ind)

if pnodal == 1:
    print("pnodal is 1")
    ids = np.unique(subcort_vol)
    print(ids)

    for s in range(0,len(ids)):
        #print(ids[s]) 
        if ids[s] > 0:
            subcort_vol[subcort_vol == ids[s]] = MaxID + s
elif pnodal == 0:
    print("pnodal is 0")
    subcort_vol[subcort_vol > 0] = MaxID + 1


parc_vol[subcort_vol > 0] = 0
parc_vol = np.squeeze(parc_vol) + subcort_vol

parc_vol_new = nib.Nifti1Image(parc_vol.astype(np.float32),parc.affine,parc.header)
nib.save(parc_vol_new,parcpath)

print("------ Python: added subcorical parcellation to ",parcpath," --------- ")



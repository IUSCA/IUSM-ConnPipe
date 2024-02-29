
import os.path
import sys 
import numpy as np
import nibabel as nib

print("------ Start Python script --------- ")

file_parc1=sys.argv[1]
print("file_parc1 is: ",file_parc1)

psubc=int(sys.argv[2])
print("psubc is: ",psubc)
print(type(psubc))

file_parc2=sys.argv[3]
print("file_parc2 is: ",file_parc2)



# head_tail = os.path.split(file_parc1)

# print(head_tail[0])
# print(head_tail[1])

# fileSubcort = ''.join([head_tail[0],'/T1_subcort_seg.nii.gz'])
# print(fileSubcort)

parc1 = nib.load(file_parc1)
parc1_vol = np.asanyarray(parc1.dataobj)
#print(parc1_vol.shape)
MaxID = np.max(parc1_vol)
#print(MaxID)

parc2 = nib.load(file_parc2)
parc2_vol = np.asanyarray(parc2.dataobj)
#ind = np.argwhere(parc2_vol == 16)
#print(ind)

if psubc == 1:
    subcortUser=os.environ['configs_T1_subcortUser']
    print("add subcortUser is: ",subcortUser)
    print(type(subcortUser))

    if subcortUser == "false":  # FSL-provided subcortical
        parc2_vol[parc2_vol == 16] = 0
        #ind = np.argwhere(parc2_vol == 16)
        #print(ind)

ids = np.unique(parc2_vol)
print(ids)

for s in range(0,len(ids)):
    #print(ids[s]) 
    if ids[s] > 0:
        parc2_vol[parc2_vol == ids[s]] = MaxID + s

parc1_vol[parc2_vol > 0] = 0
parc1_vol = np.squeeze(parc1_vol) + parc2_vol

parc_vol_new = nib.Nifti1Image(parc1_vol.astype(np.float32),parc1.affine,parc1.header)
nib.save(parc_vol_new,file_parc1)

print("------ Python: added subcorical parcellation to ",file_parc1," --------- ")



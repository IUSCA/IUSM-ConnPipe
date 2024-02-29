import os
import sys
import numpy as np

DWIpath=sys.argv[1]
# print(DWIpath)
bvalfile=sys.argv[2]
#print(dwifile)
configs_DWI_b0cut = int(sys.argv[3])
#print(configs_DWI_b0cut)
postfix = sys.argv[4]

def is_empty(any_struct):
    if any_struct:
        return False
    else:
        return True 

bval = np.loadtxt(bvalfile)
# print(bval)

B0_index = np.where(bval<=configs_DWI_b0cut)
# print(B0_index)

if is_empty(B0_index):    
    #print("No B0 volumes identified. Check quality of 0_DWI.bval") 
    print(0)
else:   
    b0file = ''.join([DWIpath,'/b0indices',postfix,'.txt'])
    ff = open(b0file,"w+")
    for i in np.nditer(B0_index):
        # fn = "/AP_b0_%d.nii.gz" % i
        # fileOut = "AP_b0_%d.nii.gz" % i
        # fileOut = ''.join([DWIpath,fn])
        ff.write("%s\n" % i)
        # print(fileOut)
    ff.close()
    print(1)

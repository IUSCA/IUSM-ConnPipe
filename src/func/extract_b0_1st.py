import sys
import numpy as np

pbval=sys.argv[1]

def is_empty(any_struct):
    if any_struct:
        return False
    else:
        return True 

#pbval=''.join([DWIpath,'/',dwifile,'.bval'])
bval = np.loadtxt(pbval)

B0_index = np.where(bval==0)
if is_empty(B0_index):    
    #print("No B0 volumes identified. Check quality of .bval") 
    print("err")
else:   
    b0_1st = np.argmin(bval)
    print(b0_1st)
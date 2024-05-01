import os
import sys
#from dipy.io import read_bvals_bvecs
import nibabel as nib
import numpy as np

def read_vectors_from_file(file_path):
    """
    Substitutes dipy's read_bvals_bvecs function.
    Reads vectors from a file and returns them as a NumPy array.
    Args:
        file_path (str): The path to the file containing vectors.
    Returns:
        numpy.ndarray: A NumPy array containing the vectors.
    """
    # Initialize a list to store vectors
    vectors = []

    # Read data from file
    with open(file_path, 'r') as file:
        for line in file:
            # Split the line by space and convert each value to float
            vector = [float(x) for x in line.strip().split()]
            # Append the vector to the list
            vectors.append(vector)

    # Convert the list of vectors to a NumPy array
    array = np.array(vectors)

    return array


fileBval=sys.argv[1]
# print("fileBval is ",fileBval)
fileBvec=sys.argv[2]
# print("fileBvec is ",fileBvec)
fileNifti=sys.argv[3]
# print("fileNifti is ",fileNifti)
p=sys.argv[4]

if len(sys.argv) > 5:
    postfix=sys.argv[5]
    pbval = ''.join([p,'/0_DWI_',postfix,'.bval'])
    pbvec = ''.join([p,'/0_DWI_',postfix,'.bvec'])
else:
    pbval = ''.join([p,'/0_DWI.bval'])
    pbvec = ''.join([p,'/0_DWI.bvec'])

# bvals, bvecs = read_bvals_bvecs(fileBval,fileBvec)
bvals = read_vectors_from_file(fileBval)
bvecs = read_vectors_from_file(fileBvec)
# print("bvals size", bvals.shape)
# print("bvecs size", bvecs.shape)

if bvals.shape[0] > 1:
    # vector is horizontal, needs to be transposed
    bvals = bvals.reshape((1,bvals.size)) 
    # print("bvals size", bvals.shape)

if bvecs.shape[0] > 3:
    # vector is horizontal, needs to be transposed
    bvecs = bvecs.T 
    # print("bvecs size", bvecs.shape)

#DWIp=''.join([p,'/',fileNifti,'.gz'])
DWI=nib.load(fileNifti)  
DWI = np.asanyarray(DWI.dataobj)

# print('DWI.shape ',DWI.shape)

if DWI.ndim < 4:
    DWI = DWI.reshape(DWI.shape + (1,))

# print('DWI.shape ',DWI.shape)

# print('bvals.shape[1] ',bvals.shape[1])
# print('bvecs.shape[1] ',bvecs.shape[1])
# print('DWI.shape[3] ',DWI.shape[3])

if bvals.shape[1] == DWI.shape[3] and bvecs.shape[1] == DWI.shape[3]:
    np.savetxt(pbval,bvals,delimiter='\n',fmt='%u')
    np.savetxt(pbvec,bvecs.T,delimiter='\t',fmt='%f')
    print('1')
else:
    print('0')

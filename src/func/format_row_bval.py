
import os
import sys
# from dipy.io import read_bvals_bvecs
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

DTIfit=sys.argv[1]
print("DTIfit ",DTIfit)
dwifile=sys.argv[2]
print("dwifile ",dwifile)
DWIpath=os.environ['DWIpath']
print("DWIpath ",DWIpath)

pbval=''.join([dwifile,'.bval'])
print('pbval',pbval)
pbvec=''.join([dwifile,'.bvec'])
print('pbvec',pbvec)

# bvals, bvecs = read_bvals_bvecs(pbval,pbvec)
bvals = read_vectors_from_file(pbval)
bvecs = read_vectors_from_file(pbvec)
 
bvals = bvals.reshape((bvals.size,1))

pbval_row=''.join([DTIfit,'/3_DWI.bval'])

np.savetxt(pbval_row,bvals.T,delimiter='\t',fmt='%u')

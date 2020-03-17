

#!/bin/bash
#
# Script: f_preproc_DWI.m adaptaion from Matlab script 
#

###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

############################################################################### 

function extract_b0_images() {
path="$1" ${python3_7} - <<END
import os
import numpy as np

DWIpath=os.environ['path']
# print(DWIpath)

def is_empty(any_struct):
    if any_struct:
        return False
    else:
        return True 

# DWIpath='/N/dc2/scratch/aiavenak/testdata/10692_1_AAK/DWI'

pbval=''.join([DWIpath,'/0_DWI.bval'])
bval = np.loadtxt(pbval)
# print(bval)

B0_index = np.where(bval<=1)
# print(B0_index)

if is_empty(B0_index):    
    #print("No B0 volumes identified. Check quality of 0_DWI.bval") 
    print(0)
else:   
    b0file = ''.join([DWIpath,"/b0file.txt"])
    ff = open(b0file,"w+")
    for i in np.nditer(B0_index):
        ff.write("%s\n" % i)
    ff.close()
    print(1)

END
}



function get_B0_temoral_info() {
path="$1" ${python3_7} - <<END
import os
import nibabel as nib
import numpy as np

DWIpath=os.environ['path']

# read in DWI daa and find number of volumes
fname=''.join([DWIpath,'/0_DWI.nii.gz'])
DWI=nib.load(fname)  
ss=DWI.shape
numVols=ss[3];

b0file = ''.join([DWIpath,"/b0file.txt"])

ff = open(b0file,"r")
ffl = ff.readlines()

Index=np.ones((numVols,1),dtype=np.int64)

for i in range(0,len(ffl)):
    ii = int(ffl[i]) 
    if ii != 1:  
        #  for every subsequent B0 the volume index increases. This provides temporal information about location of B0 volumes
        Index[ii:]=i+1


# save to file
fname=''.join([DWIpath,'/EDDY/index.txt'])
np.savetxt(fname,Index, fmt='%s')

ff.close()

END
}

function delta_EDDY() {
path="$1" ${python3_7} - <<END
import os
import nibabel as nib
import numpy as np

DWIpath=os.environ['path']

fname=''.join([DWIpath,'/0_DWI.nii.gz'])
DWI=nib.load(fname) 
DWI_vol = DWI.get_data()

fname=''.join([DWIpath,'/EDDY/eddy_output.nii.gz'])
corrDWI=nib.load(fname)
corrDWI_vol = corrDWI.get_data()

corrDWI_vol = corrDWI_vol - DWI_vol

fileOut = '/N/dc2/scratch/aiavenak/testdata/10692_1_AAK/DWI/EDDY/delta_DWI.nii.gz'
corrDWI_new = nib.Nifti1Image(corrDWI_vol.astype(np.float32),corrDWI.affine,corrDWI.header)
nib.save(corrDWI_new,fileOut)

END
}

############################################################################### 


echo "=================================="
echo "2. Eddy Correction"
echo "=================================="

# set paths to opposite phase encoded images
path_DWI_UNWARP=${DWIpath}/${configs_unwarpFolder}

path_DWI_EDDY="${DWIpath}/EDDY"

if [[ ! -d "${path_DWI_EDDY}" ]]; then
    cmd="mkdir ${path_DWI_EDDY}"
    log $cmd
    eval $cmd
fi 


# remove any existing files
rm -rf ${path_DWI_EDDY}/*
log "rm -rf ${path_DWI_EDDY}/*"

# prepare inputs for EDDY
## Create a B0 mask
if [[ -d "${path_DWI_UNWARP}"  && -e "${path_DWI_UNWARP}/topup_unwarped.nii.gz" ]]; then
    # inputs if topup was done
    fileIn="${path_DWI_UNWARP}/topup_unwarped.nii.gz"
    fileMean="${path_DWI_EDDY}/meanb0_unwarped.nii.gz"    
else
    # if topup distortion not available
    log "WARNING Topup data not found; Will run EDDY without topup field"
    # Extract B0 volumes from dataset
    res=$(extract_b0_images ${DWIpath})

    if [[ ${res} -ne "1" ]]; then
        log "WARNING: No b0 volumes identified. Check quality of 0_DWI.bval"
    else
        log "B0 indices identified: "
        B0_indices="${DWIpath}/b0file.txt"
        fileIn="${DWIpath}/0_DWI.nii.gz"
        nB0=0

        while IFS= read -r b0_index
        do 
            echo "$b0_index"
            nB0=$(echo $nB0+1 | bc) ## number of B0 indices 

            fileOut="${path_DWI_EDDY}/AP_b0_${b0_index}.nii.gz"

            cmd="fslroi ${fileIn} ${fileOut} ${b0_index} 1"
            log $cmd
            eval $cmd
        done < "$B0_indices"

    fi 
    # create a list of AP volume names
    ## list all files in EDDY directory
    ### should just be the B0 images
    filesIn=$(find ${path_DWI_EDDY} -maxdepth 1 -type f -iname "*.nii.gz")
    echo $filesIn
    B0_list=$(find ${path_DWI_EDDY} -maxdepth 1 -type f -iname "*.nii.gz" | wc -l)
    echo "$B0_list AP_b0 volumes were found in ${path_DWI_EDDY}"

    ### merge into a 4D volume
    fileOut="${path_DWI_EDDY}/all_b0_raw.nii.gz"
    cmd="fslmerge -t ${fileOut} ${filesIn}"
    log $cmd
    eval $cmd 

    ## Inputs if topup was nto done
    fileIn="${path_DWI_EDDY}/all_b0_raw.nii.gz"
    fileMean="${path_DWI_EDDY}/meanb0.nii.gz"
fi 


# Generate mean B0 image
cmd="fslmaths ${fileIn} -Tmean ${fileMean}"
log $cmd
eval $cmd 

# run FSL brain extraction to get B0 brain mask
fileBrain="${path_DWI_EDDY}/b0_brain.nii.gz"
cmd="bet ${fileMean} ${fileBrain} -f ${configs_DWI_EDDYf} -m"
log $cmd
eval $cmd

# find location of b0 volumes in dataset
## Extract b0 volumes from dataset
res=$(extract_b0_images ${DWIpath})
echo "res is ${res}"

if [[ ${res} -ne "1" ]]; then
    log "WARNING: No b0 volumes identified. Check quality of 0_DWI.bval"
else
    log "B0 indices identified: "
    B0_indices="${DWIpath}/b0file.txt"
    nB0=0
    while IFS= read -r b0_index
    do 
        echo "$b0_index"
        nB0=$(echo $nB0+1 | bc) ## number of B0 indices 
    done < "$B0_indices"

fi 

# Acquisition parameters file
## EDDY only cares about phase encoding and readout
## Unless DWI series contains both AP and PA in one 4D image, only one line is needed
## write out the acqparams.txt 
APline="0 -1 0 ${configs_DWI_readout}"
#PAline="0 1 0 ${configs_DWI_readout}"

for ((i = 0; i < $nB0; i++)); do
    echo $APline >> "${path_DWI_EDDY}/acqparams.txt"
done

# Index file
get_B0_temoral_info ${DWIpath}

# State EDDY inputs
fileIn="${DWIpath}/0_DWI.nii.gz"
fileMask="${path_DWI_EDDY}/b0_brain_mask.nii.gz"
fileBvec="${DWIpath}/0_DWI.bvec"
fileBval="${DWIpath}/0_DWI.bval"
if [[ -d "${path_DWI_UNWARP}"  && -e "${path_DWI_UNWARP}/topup_results_movpar.txt" ]]; then
    fileTopup="${path_DWI_UNWARP}/topup_results"
fi 
fileIndex="${path_DWI_EDDY}/index.txt"
fileAcqp="${path_DWI_EDDY}/acqparams.txt"
fileOut="${path_DWI_EDDY}/eddy_output"

if ${configs_DWI_repolON}; then  #Remove and interpolate outlier slices
 ## By default, an outlier is a slice whose average intensity is at
 ## least 4 standard deviations lower than what is expected by the
 ## Gaussian Process Prediction within EDDY.
    log "repolON"
    if [[ -d "${path_DWI_UNWARP}"  && -e "${path_DWI_UNWARP}/topup_results_fieldcoef.nii.gz" ]]; then

        cmd="eddy_openmp \
        --imain=${fileIn} \
        --mask=${fileMask} \
        --bvecs=${fileBvec} \
        --bvals=${fileBval} \
        --topup=${fileTopup} \
        --index=${fileIndex} \
        --acqp=${fileAcqp} \
        --repol --out=${fileOut}"
        log $cmd
        eval $cmd
    else  # no topup field available 
        cmd="eddy_openmp \
        --imain=${fileIn} \
        --mask=${fileMask} \
        --bvecs=${fileBvec} \
        --bvals=${fileBval} \
        --index=${fileIndex} \
        --acqp=${fileAcqp} \
        --repol --out=${fileOut}"
        log $cmd
        eval $cmd 

    fi

else #no repol
    log "repolOFF"
    if [[ -d "${path_DWI_UNWARP}"  && -e "${path_DWI_UNWARP}/topup_results_fieldcoef.nii.gz" ]]; then

        cmd="eddy_openmp \
        --imain=${fileIn} \
        --mask=${fileMask} \
        --bvecs=${fileBvec} \
        --bvals=${fileBval} \
        --topup=${fileTopup} \
        --index=${fileIndex} \
        --acqp=${fileAcqp} \
        --out=${fileOut}"
        log $cmd
        eval $cmd
    else  # no topup field available 
        cmd="eddy_openmp \
        --imain=${fileIn} \
        --mask=${fileMask} \
        --bvecs=${fileBvec} \
        --bvals=${fileBval} \
        --index=${fileIndex} \
        --acqp=${fileAcqp} \
        --out=${fileOut}"
        log $cmd
        eval $cmd 

    fi
fi 

# For QC purpoces this created a difference (Delta image) between raw
# and EDDY corrected diffusion data.
delta_EDDY ${DWIpath}


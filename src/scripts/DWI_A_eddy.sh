

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
path="$1" dwifile="$2" python - <<END
import os
import numpy as np

DWIpath=os.environ['path']
dwifile=os.environ['dwifile']
configs_DWI_b0cut = int(os.environ['configs_DWI_b0cut'])

# print(DWIpath)

def is_empty(any_struct):
    if any_struct:
        return False
    else:
        return True 

pbval=''.join([DWIpath,'/',dwifile,'.bval'])
bval = np.loadtxt(pbval)
# print(bval)

B0_index = np.where(bval<=configs_DWI_b0cut)
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



function get_B0_temporal_info() {
path="$1" dwifile="$2" python - <<END
import os
import nibabel as nib
import numpy as np

DWIpath=os.environ['path']
dwifile=os.environ['dwifile']
path_DWI_EDDY=os.environ['path_DWI_EDDY']

# read in DWI data and find number of volumes
fname=''.join([DWIpath,'/',dwifile,'.nii.gz'])
DWI=nib.load(fname)  
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

END
}

function delta_EDDY() {
path="$1" fileOut="$2" dwifile="$3" python - <<END
import os
import nibabel as nib
import numpy as np

path_DWI_EDDY=os.environ['path_DWI_EDDY']
print('path_DWI_EDDY',path_DWI_EDDY)
DWIpath=os.environ['path']
print('DWIpath',DWIpath)
fileOut=os.environ['fileOut']
print('fileOut',fileOut)
dwifile=os.environ['dwifile']
print('dwifile',dwifile)

fname=''.join([DWIpath,'/',dwifile,'.nii.gz'])
print('DWI file is:', fname)
DWI=nib.load(fname)  
DWI_vol = DWI.get_data()

fname=''.join([fileOut,'.nii.gz'])
print('corrDWI file is:', fname)
corrDWI=nib.load(fname)
corrDWI_vol = corrDWI.get_data()

corrDWI_vol = corrDWI_vol - DWI_vol

deltaEddy = ''.join([path_DWI_EDDY,'/delta_DWI.nii.gz'])
corrDWI_new = nib.Nifti1Image(corrDWI_vol.astype(np.float32),corrDWI.affine,corrDWI.header)
nib.save(corrDWI_new,deltaEddy)

END
}

############################################################################### 


echo "=================================="
echo "2. Eddy Correction"
echo "=================================="

log "Number of scans is ${nscanmax}"

for ((nscan=1; nscan<=nscanmax; nscan++)); do  #1 or 2 DWI scans

    # set paths to opposite phase encoded images
    path_DWI_UNWARP=${DWIpath}/${configs_unwarpFolder}

    if [[ "${nscanmax}" -eq "1" ]]; then 
        export path_DWI_EDDY="${DWIpath}/EDDY"
    elif [[ "${nscanmax}" -eq "2" ]]; then 
        export path_DWI_EDDY="${DWIpath}/EDDY${nscan}"
    fi 

    log "path_DWI_EDDY is ${path_DWI_EDDY}"

    # create output directory if one does not exist
    if [[ ! -d "${path_DWI_EDDY}" ]]; then
        cmd="mkdir ${path_DWI_EDDY}"
        log $cmd
        eval $cmd
    fi 

    # remove any existing files
    rm -rf ${path_DWI_EDDY}/*
    log "rm -rf ${path_DWI_EDDY}/*"

    if [[ "$nscanmax" -eq "1" ]]; then 
        dwifile="0_DWI"
        b0file="AP_b0"
    elif [[ "$nscanmax" -eq "2" ]]; then 
        dwifile="0_DWI_ph${nscan}"
        b0file=ph${nscan}_b0_
    fi 

    # prepare inputs for EDDY
    ## Create a B0 mask
    if [[ -d "${path_DWI_UNWARP}" ]] && [[ -e "${path_DWI_UNWARP}/topup_unwarped.nii.gz" ]]; then
        # inputs if topup was done
        fileIn="${path_DWI_UNWARP}/topup_unwarped.nii.gz"
        fileMean="${path_DWI_EDDY}/meanb0_unwarped.nii.gz"    
    else
        # if topup distortion not available
        log "WARNING Topup data not found; Will run EDDY without topup field"
        # Extract B0 volumes from dataset
        res=$(extract_b0_images ${DWIpath} ${dwifile})

        if [[ ${res} -ne "1" ]]; then
            log "WARNING: No b0 volumes identified. Check quality of ${dwifile}.bval"
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

        ## Inputs if topup was not done
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
    res=$(extract_b0_images ${DWIpath} ${dwifile})
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
    ## write out the acqparams_eddy.txt 
    APline=${DWIdcm_phase_1}

    for ((i = 0; i < $nB0; i++)); do
        echo $APline >> "${path_DWI_EDDY}/acqparams_eddy.txt"
    done

    # Index file
    get_B0_temporal_info ${DWIpath} ${dwifile}

    # State EDDY inputs
    fileIn="${DWIpath}/${dwifile}.nii.gz"
    fileBvec="${DWIpath}/${dwifile}.bvec"
    fileBval="${DWIpath}/${dwifile}.bval"
    fileJson="${DWIpath}/${dwifile}.json"

    fileMask="${path_DWI_EDDY}/b0_brain_mask.nii.gz"

    if [[ -d "${path_DWI_UNWARP}" ]] && [[ -e "${path_DWI_UNWARP}/topup_results_movpar.txt" ]]; then
        fileTopup="${path_DWI_UNWARP}/topup_results"
    fi 
    fileIndex="${path_DWI_EDDY}/index.txt"
    fileAcqp="${path_DWI_EDDY}/acqparams_eddy.txt"
    fileOut="${path_DWI_EDDY}/eddy_output"

    if ${configs_DWI_repolON}; then  #Remove and interpolate outlier slices
    ## By default, an outlier is a slice whose average intensity is at
    ## least 4 standard deviations lower than what is expected by the
    ## Gaussian Process Prediction within EDDY.
        log "repolON"
        if [[ -d "${path_DWI_UNWARP}" ]] && [[ -e "${path_DWI_UNWARP}/topup_results_fieldcoef.nii.gz" ]]; then
            if ${configs_DWI_MBjson}; then
                cmd="eddy_openmp \
                --imain=${fileIn} \
                --mask=${fileMask} \
                --bvecs=${fileBvec} \
                --bvals=${fileBval} \
                --topup=${fileTopup} \
                --index=${fileIndex} \
                --acqp=${fileAcqp} \
                --repol --json=${fileJson} --out=${fileOut}"
            else 
                cmd="eddy_openmp \
                --imain=${fileIn} \
                --mask=${fileMask} \
                --bvecs=${fileBvec} \
                --bvals=${fileBval} \
                --topup=${fileTopup} \
                --index=${fileIndex} \
                --acqp=${fileAcqp} \
                --repol --out=${fileOut}"
            fi 
        else  # no topup field available 
            if ${configs_DWI_MBjson}; then
                cmd="eddy_openmp \
                --imain=${fileIn} \
                --mask=${fileMask} \
                --bvecs=${fileBvec} \
                --bvals=${fileBval} \
                --index=${fileIndex} \
                --acqp=${fileAcqp} \
                --repol --json=${fileJson} --out=${fileOut}"
            else 
                cmd="eddy_openmp \
                --imain=${fileIn} \
                --mask=${fileMask} \
                --bvecs=${fileBvec} \
                --bvals=${fileBval} \
                --index=${fileIndex} \
                --acqp=${fileAcqp} \
                --repol --out=${fileOut}"
            fi 
        fi
        log $cmd
        eval $cmd
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
        else  # no topup field available 
            cmd="eddy_openmp \
            --imain=${fileIn} \
            --mask=${fileMask} \
            --bvecs=${fileBvec} \
            --bvals=${fileBval} \
            --index=${fileIndex} \
            --acqp=${fileAcqp} \
            --out=${fileOut}" 
        fi
        log $cmd
        eval $cmd
    fi 

    # For QC purpoces this created a difference (Delta image) between raw
    # and EDDY corrected diffusion data.
    log "Computing Delta Eddy image"
    delta_EDDY ${DWIpath} ${fileOut} ${dwifile}
    log "Delta Eddy saved"
done 
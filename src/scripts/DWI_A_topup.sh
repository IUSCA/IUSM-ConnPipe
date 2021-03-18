

#!/bin/bash
#
# Script: fMRI_A adaptaion from Matlab script 
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
path="$1" dwifile="$2" nscan="$3" python - <<END
import os
import numpy as np

DWIpath=os.environ['path']
# print(DWIpath)
dwifile=os.environ['dwifile']
#print(dwifile)
configs_DWI_b0cut = int(os.environ['configs_DWI_b0cut'])
#print(configs_DWI_b0cut)
nscan = os.environ['nscan']

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
    b0file = ''.join([DWIpath,'/b0indices',nscan,'.txt'])
    ff = open(b0file,"w+")
    for i in np.nditer(B0_index):
        # fn = "/AP_b0_%d.nii.gz" % i
        # fileOut = "AP_b0_%d.nii.gz" % i
        # fileOut = ''.join([DWIpath,fn])
        ff.write("%s\n" % i)
        # print(fileOut)
    ff.close()
    print(1)

END
}


############################################################################### 


echo "=================================="
echo "1. Topup Field Estimation"
echo "=================================="

# set paths to opposite phase encoded images
path_DWI_UNWARP=${DWIpath}/${configs_unwarpFolder}

path_DWIdcmPA=${path_DWI_UNWARP}/${configs_dcmPA}

if [[ ! -d "${path_DWI_UNWARP}" ]]; then
    log "WARNING No UNWARP dicom directory found! Skipping topup."
elif [[ ! -d "${path_DWIdcmPA}" ]] && [[ ${nscanmax} -eq 1 ]]; then
    log "WARNING No dicom directory found within UNWARP! Skipping topup."    
elif [ -z "$(ls -A ${path_DWIdcmPA})" ] && [[ ${nscanmax} -eq 1 ]]; then  #check if dir is empty 
    log "No files found within UNWARP dicom directory! Skipping topup."
else
    # remove files from previous run(s)
    log "rm -f ${path_DWI_UNWARP}/.nii.gz \
        ${path_DWI_UNWARP}/.log \
        ${path_DWI_UNWARP}/.txt"

    rm -f ${path_DWI_UNWARP}/*.nii.gz \
    ${path_DWI_UNWARP}/*.log \
    ${path_DWI_UNWARP}/*.txt

    log "Number of scans is ${nscanmax}"
    # Extract b0 volumes from dataset
    for ((nscan=1; nscan<=nscanmax; nscan++)); do  #1 or 2 DWI scans

        if [[ "$nscanmax" -eq 1 ]]; then 
            dwifile="0_DWI"
            b0file="AP_b0"
            
            # remove existing files
            if [[ -f "${path_DWI_UNWARP}/PA_b0.nii.gz" ]]; then 
                cmd="rm -rf ${path_DWI_UNWARP}/PA_b0.nii.gz"
                log $cmd
                eval $cmd  
            fi 
            # Dicom import the PA volume
            fileLog="${path_DWI_UNWARP}/dcm2niix.log"
            cmd="dcm2niix -f PA_b0 -o ${path_DWI_UNWARP} -v y ${path_DWIdcmPA} > ${fileLog}"
            log $cmd
            eval $cmd 
            # gzip nifti image
            cmd="gzip ${path_DWI_UNWARP}/PA_b0.nii"
            log $cmd 
            eval $cmd 


            # Check if the readout time is consistent with 
            # the readout-time contained in the json file
            dcm2niix_json="${path_DWI_UNWARP}/PA_b0.json"

            if [[ -e ${dcm2niix_json} ]]; then
                TotalReadoutTime=`cat ${dcm2niix_json} | ${EXEDIR}/src/func/jq-linux64 '.TotalReadoutTime'`
                
                echo "TotalReadoutTime from ${dcm2niix_json} is ${TotalReadoutTime}"
                diff=$(echo "$TotalReadoutTime - $configs_DWI_readout" | bc)

                echo "diff = TotalReadoutTime - configs_DWI_readout = $diff"

                if [[ $(bc <<< "$diff >= 0.1") -eq 1 ]] || [[ $(bc <<< "$diff <= -0.1") -eq 1 ]]; then
                    log "ERROR Calculated readout time not consistent with readout time provided by dcm2niix"
                    exit 1
                fi 

                PhaseEncodingDirection=`cat ${dcm2niix_json} | ${EXEDIR}/src/func/jq-linux64 '.PhaseEncodingDirection'`
                
                echo "PhaseEncodingDirection from ${dcm2niix_json} is ${PhaseEncodingDirection}"            

                if [[ "${PhaseEncodingDirection}" == '"j-"' ]]; then
                    if [[ "${nscan}" -eq "1" ]]; then 
                        DWIdcm_phase_1="0 -1 0 ${configs_DWI_readout}"
                        log "${DWIdcm_phase_1}"
                    elif [[ "${nscan}" -eq "2" ]]; then 
                        DWIdcm_phase_2="0 -1 0 ${configs_DWI_readout}"
                        log "${DWIdcm_phase_2}"
                    fi 
                elif [[ "${PhaseEncodingDirection}" == '"j"' ]]; then
                    if [[ "${nscan}" -eq "1" ]]; then 
                        DWIdcm_phase_1="0 1 0 ${configs_DWI_readout}"
                        log "${DWIdcm_phase_1}"
                    elif [[ "${nscan}" -eq "2" ]]; then 
                        DWIdcm_phase_2="0 1 0 ${configs_DWI_readout}"
                        log "${DWIdcm_phase_2}"
                    fi 
                else 
                    log "WARNING PhaseEncodingDirection not implemented or unknown"
                fi                 
            fi 

        elif [[ "$nscanmax" -eq 2 ]]; then 
            dwifile="0_DWI_ph${nscan}"
            b0file=ph${nscan}_b0_
        fi 

        res=$(extract_b0_images ${DWIpath} ${dwifile} ${nscan})
        echo "res is ${res}"

        if [[ "${res}" -ne "1" ]]; then
            log "WARNING: No b0 volumes identified. Check quality of 0_DWI.bval"
        else
            log "B0 indices identified: "
            B0_indices="${DWIpath}/b0indices${nscan}.txt"
            fileIn="${DWIpath}/${dwifile}.nii.gz"
            nB0=0
            while IFS= read -r b0_index
            do 
                echo "$b0_index"
                nB0=$(echo $nB0+1 | bc) ## number of B0 indices 

                fileOut="${path_DWI_UNWARP}/${b0file}${b0_index}.nii.gz"

                cmd="fslroi ${fileIn} ${fileOut} ${b0_index} 1"
                log $cmd
                eval $cmd
            done < "$B0_indices"

            # rm -f ${B0_indices}  
        fi 
    done 
fi 

# # Dicom import the PA volume
# ## remove existing files
# cmd="rm -rf ${path_DWI_UNWARP}/PA_b0.nii.gz"
# log $cmd
# eval $cmd 

# ## dicom import
# cmd="dcm2niix -f PA_b0 -o ${path_DWI_UNWARP} -v y ${path_DWIdcmPA}"
# log $cmd
# eval $cmd > "${path_DWI_UNWARP}/dcm2niix.log"  ##save log file

# ## gzip output image
# cmd="gzip ${path_DWI_UNWARP}/PA_b0.nii"
# log $cmd
# eval $cmd 

# Concatenate AP and PA into a single 4D volume.
# create a list of AP volume names

## list all the files in unwarp dir
# declare -a fileList
# while IFS= read -r -d $'\0' REPLY; do 
#     fileList+=( "$REPLY" )
# done < <(ffind ${path_DWI_UNWARP} -maxdepth 1 -type f -iname "*.nii.gz" -print0)

## list all the files in unwarp dir
filesIn=$(find ${path_DWI_UNWARP} -maxdepth 1 -type f -iname "*.nii.gz")
echo $filesIn
B0_list=$(find ${path_DWI_UNWARP} -maxdepth 1 -type f -iname "*.nii.gz" | wc -l)
echo "$B0_list volumes were found in ${path_DWI_UNWARP}"

## merge into a 4D volume
fileOut="${path_DWI_UNWARP}/All_b0.nii.gz"

cmd="fslmerge -t ${fileOut} ${filesIn}"
log $cmd
eval $cmd 

## generate acqparams.txt necessary for topup
PAcount=$(echo $B0_list - $nB0 | bc)

# APline="0 -1 0 ${configs_DWI_readout}"
# PAline="0 1 0 ${configs_DWI_readout}"

APline=${DWIdcm_phase_1}
PAline=${DWIdcm_phase_2}

for ((i = 0; i < $nB0; i++)); do
    echo $APline >> "${path_DWI_UNWARP}/acqparams.txt"
done


for ((i = 0; i < $PAcount; i++)); do
    echo $PAline >> "${path_DWI_UNWARP}/acqparams.txt"
done

# Run Topup
fileIn="${path_DWI_UNWARP}/All_b0.nii.gz"
fileParams="${path_DWI_UNWARP}/acqparams.txt"
fileOutName="${path_DWI_UNWARP}/topup_results"
fileOutField="${path_DWI_UNWARP}/topup_field"
fileOutUnwarped="${path_DWI_UNWARP}/topup_unwarped"

cmd="topup --imain=${fileIn} \
    --datain=${fileParams} \
    --out=${fileOutName} \
    --fout=${fileOutField} \
    --iout=${fileOutUnwarped}"

    log $cmd
    #eval $cmd 
  

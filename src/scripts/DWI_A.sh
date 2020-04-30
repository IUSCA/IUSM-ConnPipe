
#!/bin/bash
#
# Script: DWI_A adaptaion from Matlab script 
#

###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

###############################################################################

function read_bvals_bvecs() {
path="$1" python - <<END
import os
from dipy.io import read_bvals_bvecs
import nibabel as nib
import numpy as np

p=os.environ['path']
# p='/N/dc2/scratch/aiavenak/testdata/10692_1_AAK/DWI'

pbval=''.join([p,'/0_DWI.bval'])
pbvec=''.join([p,'/0_DWI.bvec'])

bvals, bvecs = read_bvals_bvecs(pbval,pbvec)
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

DWIp=''.join([p,'/0_DWI.nii.gz'])
DWI=nib.load(DWIp)  

# print('bvals.shape[1] ',bvals.shape[1])
# print('bvecs.shape[1] ',bvecs.shape[1])
# print('DWI.shape[3] ',DWI.shape[3])

if bvals.shape[1] == DWI.shape[3] and bvecs.shape[1] == DWI.shape[3]:
    np.savetxt(pbval,bvals,delimiter='\n',fmt='%u')
    np.savetxt(pbvec,bvecs.T,delimiter='\t',fmt='%f')
    print('1')
else:
    print('0')

END
}

###############################################################################

if [[ -d ${DWIpath} ]]; then

    log "DWI_A processing for subject ${SUBJ}"

    # Generate an acqparams text file based on number of field maps.
    if [ !-z ${configs_DWI_readout} ]; then
        cmd="${EXEDIR}/src/scripts/get_readout.sh ${DWIpath}" 
        log $cmd
        export configs_DWI_readout=`$cmd`
        echo "configs_DWI_readout -- ${configs_DWI_readout}"
    fi


    # ### Convert dcm2nii
    if ${flags_DWI_dcm2niix}; then

        echo "=================================="
        echo "0. Dicom to NIFTI import"
        echo "=================================="

        path_DWIdcm=${DWIpath}/${configs_dcmFolder}
        #echo "path_DWIdcm is -- ${path_DWIdcm}"

        # Identify DICOMs
        declare -a dicom_files
        while IFS= read -r -d $'\0' dicomfile; do 
            dicom_files+=( "$dicomfile" )
        done < <(find ${path_DWIdcm} -iname "*.${configs_dcmFiles}" -print0 | sort -z)

        if [ ${#dicom_files[@]} -eq 0 ]; then 

            echo "No dicom (.${configs_dcmFiles}) images found."
            echo "Please specify the correct file extension of dicom files by setting the configs_dcmFiles flag in the config file"
            echo "Skipping further analysis"
            exit 1

        else

            echo "There are ${#dicom_files[@]} dicom files in ${path_DWIdcm} "

            fileNii="0_DWI"

            rm -rf ${DWIpath}/${fileNii}*
            log "rm -rf ${fileNii}"

            fileLog="${DWIpath}/dcm2niix.log"
            cmd="dcm2niix -f ${fileNii} -o ${DWIpath} -v y ${path_DWIdcm} > ${fileLog}"
            log $cmd
            eval $cmd 

            cmd="gzip ${DWIpath}/0_DWI.nii"
            log $cmd 
            eval $cmd 
        fi

        # Check if the readout time is consistent with the readout-time contained in the json file
        dcm2niix_json="${DWIpath}/0_DWI.json"

        if [[ -e ${dcm2niix_json} ]]; then
            TotalReadoutTime=`cat ${dcm2niix_json} | ${EXEDIR}/src/func/jq-linux64 '.TotalReadoutTime'`
            
            echo "TotalReadoutTime from ${dcm2niix_json} is ${TotalReadoutTime}"
            diff=$(echo "$TotalReadoutTime - $configs_DWI_readout" | bc)

            echo "TotalReadoutTime - configs_DWI_readout is $diff"

            if [[ $(bc <<< "$diff >= 0.1") -eq 1 ]] || [[ $(bc <<< "$diff <= -0.1") -eq 1 ]]; then
                log "ERROR Calculated readout time not consistent with readout time provided by dcm2niix"
            fi    
        fi 


        echo "=================================="
        echo "0.5. Bvec & Bval File Format"
        echo "=================================="

        if [[ ! -e "${DWIpath}/0_DWI.bval" ]] && [[ ! -e "${DWIpath}/0_DWI.bvec" ]]; then
            log "WARNIGN Bvec and/or Bval files do not exist. Skipping further analyses"
            exit 1
        else
            out=$(read_bvals_bvecs ${DWIpath})
            log "out is ${out}"
            if [[ $out -eq 1 ]]; then
                log "# Bvec and Bval files written in column format with tab delimiter"
            else
                log "#WARNING Bvec and/or Bval values do not match number of volumes. Exiting Analysis"
            fi 
        fi 
    fi


    #### Read info from the headers of the dicom fMRI volumes
    if ${flags_DWI_topup}; then

        cmd="${EXEDIR}/src/scripts/DWI_A_topup.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at DWI_A_topup. exiting."
            exit 1
        fi  
    fi


    #### FSL Eddy
    if ${flags_DWI_eddy}; then

        cmd="${EXEDIR}/src/scripts/DWI_A_eddy.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at DWI_A_eddy. exiting."
            exit 1
        fi  
    fi


    #### DTIfit
    if ${flags_DWI_DTIfit}; then

        cmd="${EXEDIR}/src/scripts/DWI_A_DTIfit.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at DWI_A_eddy. exiting."
            exit 1
        fi  
    fi



else 

    log "WARNING Subject DWI directory does not exist; skipping DWI processing for subject ${SUBJ}"

fi 
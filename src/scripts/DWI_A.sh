
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
fileBval = os.environ['fileBval']
# print("fileBval is ",fileBval)
fileBvec = os.environ['fileBvec']
# print("fileBvec is ",fileBvec)
fileNifti = os.environ['fileNifti']
# print("fileNifti is ",fileNifti)

# pbval=''.join([p,'/0_DWI.bval'])
# pbvec=''.join([p,'/0_DWI.bvec'])
pbval = ''.join([p,'/',fileBval])
pbvec = ''.join([p,'/',fileBvec])
pbvec = ''.join([p,'/',fileBvec])


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

DWIp=''.join([p,'/',fileNifti,'.gz'])
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

    # Calculate readout time
    if [[ ! -z "${configs_DWI_readout}" ]]; then
        # if two DICOM directories exist 
        if [[ ! -z "${configs_DWI_dcmFolder1}" ]] && [[ ! -z "${configs_DWI_dcmFolder2}" ]]; then

            DWIdir1="${DWIpath}/${configs_DWI_dcmFolder1}"
            DWIdir2="${DWIpath}/${configs_DWI_dcmFolder2}"

            log "${configs_DWI_dcmFolder1} and ${configs_DWI_dcmFolder2} have been defined by user"

            if [[ -d "${DWIdir1}" ]] && [[ -d "${DWIdir2}" ]]; then

                export nscanmax=2 # DWI acquired in two phase directions (e.g., AP and PA)
                
                jsonfile="null"

                cmd="${EXEDIR}/src/scripts/get_readout.sh ${jsonfile} ${DWIdir1} DWI" 
                log $cmd
                DWIreadout1=`$cmd`
                log "DWIreadout1 = ${DWIreadout1}"

                cmd="${EXEDIR}/src/scripts/get_readout.sh ${jsonfile} ${DWIdir2} DWI" 
                log $cmd
                DWIreadout2=`$cmd`
                log "DWIreadout2 = ${DWIreadout2}"

                if (( $(echo "${DWIreadout1} == ${DWIreadout2}" |bc -l) )) ; then
                    export configs_DWI_readout=${DWIreadout1}
                    echo "configs_DWI_readout -- ${configs_DWI_readout}"                    
                    DWI1dcm_niifile="0_DWI_ph1"
                    DWI2dcm_niifile="0_DWI_ph2"

                else
                    log "WARNING DWI readout values do not match! Exiting..."
                    exit 1
                fi
            else
                log "WARNING ${DWIdir1} and/or ${DWIdir2} not found!. Exiting..."
                exit 1
            fi 

        else

            DWIdir1="${DWIpath}/${configs_DWI_dcmFolder}"

            log "${DWIdir1} has been defined by user"

            export nscanmax=1  # DWI acquired in one phase direction (b0's non-withstanding)
          
            if [[ -d "${DWIdir1}" ]]; then 
            
                jsonfile="null"

                cmd="${EXEDIR}/src/scripts/get_readout.sh ${jsonfile} ${DWIdir1} DWI" 
                log $cmd
                export configs_DWI_readout=`$cmd`
                echo "configs_DWI_readout -- ${configs_DWI_readout}"
                DWI1dcm_niifile="0_DWI"

            else 
                log "WARNING ${DWIdir1} not found!. Exiting..."
                exit 1    
            fi 
        fi 
    fi

    for ((nscan=1; nscan<=nscanmax; nscan++)); do  #1 or 2 DWI scans

        if [[ "$nscan" -eq 1 ]]; then 
            path_DWIdcm=${DWIdir1}
            fileNii=${DWI1dcm_niifile}
        elif [[ "$nscan" -eq 2 ]]; then 
            path_DWIdcm=${DWIdir2}
            fileNii=${DWI2dcm_niifile}
        fi 
            
        log "path_DWIdcm is -- ${path_DWIdcm}"

        export fileNifti="${fileNii}.nii"
        export fileJson="${fileNii}.json"
        export fileBval="${fileNii}.bval"
        export fileBvec="${fileNii}.bvec"


        #### Convert dcm2nii
        if ${flags_DWI_dcm2niix}; then

            echo "=================================="
            echo "0. Dicom to NIFTI import"
            echo "=================================="

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

                # Remove any existing .nii/.nii.gz images from dicom directories.
                rm -rf ${DWIpath}/${fileNii}*
                log "rm -rf ${fileNii}"
                # Create nifti bvec and bval files.
                fileLog="${DWIpath}/dcm2niix.log"
                cmd="dcm2niix -f ${fileNii} -o ${DWIpath} -v y ${path_DWIdcm} > ${fileLog}"
                log $cmd
                eval $cmd 
                # gzip nifti image
                cmd="gzip ${DWIpath}/${fileNifti}"
                log $cmd 
                eval $cmd 
            fi
        fi


        # Check if the readout time is consistent with the readout-time contained in the json file
        dcm2niix_json="${DWIpath}/${fileJson}"

        if [[ -e ${dcm2niix_json} ]]; then

            TotalReadoutTime=`cat ${dcm2niix_json} | ${EXEDIR}/src/func/jq-linux64 '.TotalReadoutTime'`            
            echo "TotalReadoutTime from ${dcm2niix_json} is ${TotalReadoutTime}"
            AccF=`cat ${dcm2niix_json} | ${EXEDIR}/src/func/jq-linux64 '.ParallelReductionFactorInPlane'`
            echo "ParallelReductionFactorInPlane from ${dcm2niix_json} is ${AccF}"
            if [ -z "${AccF}" ] || [[ "${AccF}" -eq "null" ]]; then
                AccF=1
            fi 
            TotalReadoutTime=$(bc <<< "scale=8 ; ${TotalReadoutTime} / ${AccF}")
            echo "TotalReadoutTime/AccF = ${TotalReadoutTime}"

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
            
            export DWIdcm_phase_1
            export DWIdcm_phase_2


            DWIdcm_SliceTiming=`cat ${dcm2niix_json} | ${EXEDIR}/src/func/jq-linux64 '.SliceTiming'`
            
            echo "SliceTiming from ${dcm2niix_json} is ${DWIdcm_SliceTiming}"            

        fi  

        echo "=================================="
        echo "0.5. Bvec & Bval File Format"
        echo "=================================="

        if [[ ! -e "${DWIpath}/${fileBval}" ]] && [[ ! -e "${DWIpath}/${fileBvec}" ]]; then
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

    done

    if [[ "${nscanmax}" -eq "1" ]]; then 
        log "Single phase direction"
    elif [[ "${nscanmax}" -eq "2" ]]; then 
        log "Two phase directions"
        #### TO BE DEVELOPED LATER #######
        # fileIn1="${DWIpath}/0_DWI_ph1.nii.gz"
        # fileIn2="${DWIpath}/0_DWI_ph2.nii.gz"
        # fileOut="${DWIpath}/0_DWI"

        # if [[ -f ${fileIn1} ]] && [[ -f ${fileIn2} ]]; then 
        #     rm -rf ${DWIpath}/0_DWI.nii*
        #     log="rm -rf ${DWIpath}/0_DWI.nii"

        #     cmd="fslmerge -t ${fileOut} ${fileIn1} ${fileIn2}"
        #     log $cmd
        #     eval $cmd 
        # else 
        #     log "WARNING  ${fileIn1} and/or ${fileIn2} not found. Exiting.."
        #     exit 1
        # fi 
    fi 

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
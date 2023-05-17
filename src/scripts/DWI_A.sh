
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

pbval = ''.join([p,'/0_DWI.bval'])
pbvec = ''.join([p,'/0_DWI.bvec'])

bvals, bvecs = read_bvals_bvecs(fileBval,fileBvec)
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

if [[ -d ${DWIpath_raw} ]]; then

    log "DWI_A processing for subject ${SUBJ}"
    log "${DWIpath_raw} has been defined by user"

    # count the number of nii images in dir
    export nscanmax=`ls ${DWIpath_raw}/*nii* | wc -l`

    # Calculate readout time
    if [[ ! -z "${configs_DWI_readout}" ]]
    then  
        if [[ -d "${DWIpath_raw}" ]]
		then
	    	if [[ "$nscanmax" -eq 1 ]]
	    	then
				jsonfile=`ls ${DWIpath_raw}/*json`
                # find TotalReadoutTime
    			export configs_DWI_readout=`cat ${jsonfile} | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_TotalReadoutTime}`
	    	elif [[ "$nscanmax" > 1 ]]
	    	then
				jsonfile1=`ls ${DWIpath_raw}/*run-1_dwi.json`
				SEreadOutTime1=`cat ${jsonfile1} | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_TotalReadoutTime}`
				jsonfile2=`ls ${DWIpath_raw}/*run-1_dwi.json`
				SEreadOutTime2=`cat ${jsonfile2} | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_TotalReadoutTime}`
				# ADD THE CHECK IF TWO ARE EQUAL, IF THEY ARE NOT ITS NOT A DEALBRACKER, THEY JUST BOTH NEED TO BE
				# CARRIED FORWARD INTO TOPUP
				# RIGHT NOW DEFAULTING TO FIRST VALUE
				export configs_DWI_readout=${SEreadOutTime1}  		
	    	else
				log "WARNING: No *nii* files in: ${DWIpath_raw}"
				exit 1 
	    	fi          
        else
			log "WARNING ${DWIpath_raw} not found!. Exiting..."
			exit 1 
		fi
    else
 		echo "configs_DWI_readout -- ${configs_DWI_readout}"     
    fi 
                

    for ((nscan=1; nscan<=nscanmax; nscan++)); do  #1 or 2 DWI scans
#-------------------------------------------------------------------------------------------#
# THIS WHOLE SECTION WILL NEED TO BE RE-DONE TO BE BIDS FORMAT
# DICOMS WILL BE IN A 'SOURCE' DIRECTORY WITHIN THE PROJECT DIRECTORY
# DICMOS WILL BE READ FROM THERE AND COPIED INTO THE 'RAW' DIRECTORY IN BIDS FORMAT 
# OR SOMETHING LIKE THAT

       # if [[ "$nscan" -eq 1 ]]; then 
           # path_DWIdcm=${DWIpath_raw}
        #    fileNii=${DWI1dcm_niifile}
       # elif [[ "$nscan" -eq 2 ]]; then 
           # path_DWIdcm=${DWIdir2}
        #    fileNii=${DWI2dcm_niifile}
       # fi 
            
      #  log "path_DWIdcm is -- ${path_DWIdcm}"
		if [[ "$nscanmax" -eq 1 ]]
    	then
			export fileNifti=`ls ${DWIpath_raw}/*_dwi.nii*`
		    export fileJson=`ls ${DWIpath_raw}/*_dwi.json`
		    export fileBval=`ls ${DWIpath_raw}/*_dwi.bval`
		    export fileBvec=`ls ${DWIpath_raw}/*_dwi.bvec`
		else
			if [[ "$nscan" -eq 1 ]]
			then 
				export fileNifti=`ls ${DWIpath_raw}/*run-1_dwi.nii*`
				export fileJson=`ls ${DWIpath_raw}/*run-1_dwi.json`
				export fileBval=`ls ${DWIpath_raw}/*run-1_dwi.bval`
				export fileBvec=`ls ${DWIpath_raw}/*run-1_dwi.bvec`
			elif [[ "$nscan" -eq 2 ]]
			then 
				export fileNifti=`ls ${DWIpath_raw}/*run-2_dwi.nii*`
				export fileJson=`ls ${DWIpath_raw}/*run-2_dwi.json`
				export fileBval=`ls ${DWIpath_raw}/*run-2_dwi.bval`
				export fileBvec=`ls ${DWIpath_raw}/*run-2_dwi.bvec`
			fi
		fi 

        #### Convert dcm2nii
        if ${flags_DWI_dcm2niix}; then

            echo "=================================="
            echo "0. Dicom to NIFTI import"
            echo "=================================="

            # Identify DICOMs
            declare -a dicom_files
            while IFS= read -r -d $'\0' dicomfile; do 
                dicom_files+=( "$dicomfile" )
            done < $(find ${path_DWIdcm} -iname "*.${configs_dcmFiles}" -print0 | sort -z)

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
# END OF DICOM IMPORT
#--------------------------------------------------------------------------------------------------------#
# THIS STUFF WILL ALSO BE REDONE, WITH SIEMENS ITS SAFE TO TRUST DCM2NIIX READOUT 
# THIS WILL NEED TO BE CONFIRMED FOR ge
        # Check if the readout time is consistent with the readout-time contained in the json file
  #      dcm2niix_json="${DWIpath}/${fileJson}"

        if [[ -e ${fileJson} ]]; then
#
#           TotalReadoutTime=`cat ${dcm2niix_json} | ${EXEDIR}/src/func/jq-linux64 '.TotalReadoutTime'`            
#            echo "TotalReadoutTime from ${dcm2niix_json} is ${TotalReadoutTime}"
#            AccF=`cat ${dcm2niix_json} | ${EXEDIR}/src/func/jq-linux64 '.ParallelReductionFactorInPlane'`
#            echo "ParallelReductionFactorInPlane from ${dcm2niix_json} is ${AccF}"
#            if [ -z "${AccF}" ] || [[ "${AccF}" -eq "null" ]]; then
#                AccF=1
#            fi 
#            TotalReadoutTime=$(bc <<< "scale=8 ; ${TotalReadoutTime} / ${AccF}")
#            echo "TotalReadoutTime/AccF = ${TotalReadoutTime}"
#
#            diff=$(echo "$TotalReadoutTime - $configs_DWI_readout" | bc)
#
#            echo "diff = TotalReadoutTime - configs_DWI_readout = $diff"
#
#            if [[ $(bc <<< "$diff >= 0.1") -eq 1 ]] || [[ $(bc <<< "$diff <= -0.1") -eq 1 ]]; then
#                log "ERROR Calculated readout time not consistent with readout time provided by dcm2niix"
#                exit 1
#            fi 
#
            PhaseEncodingDirection=`cat ${fileJson} | ${EXEDIR}/src/func/jq-linux64 '.PhaseEncodingDirection'`
            echo "PhaseEncodingDirection from ${fileJson} is ${PhaseEncodingDirection}"            

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


           DWIdcm_SliceTiming=`cat ${fileJson} | ${EXEDIR}/src/func/jq-linux64 '.SliceTiming'`
            
            echo "SliceTiming from ${fileJson} is ${DWIdcm_SliceTiming}"            

        fi  

        echo "=================================="
        echo "0.5. Bvec & Bval File Format"
        echo "=================================="

        if ${configs_DWI_DICOMS2_B0only} && [[ "$nscan" -eq 2 ]]; then
            # # check that no bvec and bval files were generated for DICOMS2
            # if [[ ! -e "${DWIpath}/${fileBval}" ]] && [[ ! -e "${DWIpath}/${fileBvec}" ]]; then

                log "Creating dummy Bvec and/or Bval files ${DWIpath}/${fileBval} and ${DWIpath}/${fileBvec}"
                # find the number of B0's as the 4th dimension
                numB0=$(fslinfo ${DWIpath}/${fileNifti}.gz | awk '/^dim4/' | awk '{split($0,a," "); {print a[2]}}')
                log "There is/are ${numB0} B0 in ${DWIpath}/${fileNifti}.gz"

                # create dummy B0 files
                dummy_bvec=`echo -e '0 \t 0 \t  0 \t'` 
                for ((k=0; k<${numB0}; k++)); do
                    echo ${dummy_bvec} >> ${DWIpath}/${fileBvec}
                    echo "0" >> ${DWIpath}/${fileBval}
                done

            # else  
            #     log "WARNING. Bvec and/or Bval files ${DWIpath}/${fileBval} and ${DWIpath}/${fileBvec} already exist."
            #     log "WARNING. Please check whether thse files need to be delted, or if configs_DWI_DICOMS2_B0only should be set to 'false'. Exiting"   
            #     exit 1      
            # fi 

        else  

            if [[ ! -e "${fileBval}" ]] && [[ ! -e "${fileBvec}" ]]; then
                log "WARNING Bvec and/or Bval files do not exist. Skipping further analyses"
                exit 1
            else
                out=$(read_bvals_bvecs ${DWIpath})
                log "out is ${out}"
				export fileBval="${DWIpath}/0_DWI.bval"
				export fileBvec="${DWIpath}/0_DWI.bvec"
                if [[ $out -eq 1 ]]; then
                    log "# Bvec and Bval files written in column format with tab delimiter"
                else
                    log "#WARNING Bvec and/or Bval values do not match number of volumes. Exiting Analysis"
					exit 1
                fi 
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
# TOPUP NEEDS TO BE EDITED FOR BIDS
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
# WILL NEED SOME UPDATES FOR TWO SCAN RUNS AND RUNS WITH TOPUP TO RUN BIDS DATA 
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

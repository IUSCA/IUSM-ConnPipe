
#!/bin/bash
#
# Script: T1_PREPARE_A adaptaion from Matlab script 
#

###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh



if [[ -d "$T1path/${configs_dcmFolder}" ]]; then
	if [[ "$(ls -A $T1path/${configs_dcmFolder})" ]]; then 

        log "T1_PREPARE_A"

		##### DICOM 2 nifti ######

		if ${flags_T1_dcm2niix}; then
			# if .IMA or .IMA.dcm or .dcm files exis inside T1/DICOMS
			dicomfiles=`find $T1path/${configs_dcmFolder} -maxdepth 1 -name "*.${configs_dcmFiles}*" | wc -l`
			if [[ $dicomfiles -eq 0 ]]; then 
				echo "No dicom (.${configs_dcmFiles}) images found."
				echo "Please specify the correct file extension of dicom files by setting the configs_dcmFiles flag in the config file"
				echo "Skipping further analysis"
				exit 1				
			fi


			niifiles=`find $T1path -maxdepth 1 -name "*.nii*" | wc -l`
			if [[ $niifiles != 0 ]]; then 
				# Remove existing nifti images.
				log "rm $T1path/.${configs_niiFiles}"
				rm $T1path/*.${configs_niiFiles}*			
			fi
			
			# Converting DICOM to Nifti
			log "DICOM->NIFTI"
			cmd="dcm2niix -f T1 -o $T1path -v y -x y -b y $T1path/${configs_dcmFolder} > $T1path/dcm2niix.log"
			log $cmd
			eval $cmd 
			if [[ $? != 0 ]];  then
				echoerr "dcm2nii exit status not zero. exiting."
				exit 1
			else
				cmd="mv $T1path/${configs_T1}.nii $T1path/${configs_T1}_orig.nii"
				log $cmd
				eval $cmd 
				if ${configs_T1_useCropped}; then
					gzip -f $T1path/${configs_T1}_Crop_1.nii
					mv $T1path/${configs_T1}_Crop_1.nii.gz $T1path/${configs_T1}.nii.gz
				else
					gzip -f $T1path/${configs_T1}_orig.nii
					mv $T1path/${configs_T1}_orig.nii.gz $T1path/${configs_T1}.nii.gz
				fi
			fi			
		fi

		##### T1 denoiser ######
		
		if ${flags_T1_denoiser}; then
			#singularity pull --name ants.simg docker://brainlife/ants 
			#singularity shell ants.simg 
			fileIn="$T1path/${configs_T1}.nii.gz"
			if ${flag_ANTS}; then 
				cmd="DenoiseImage -v -d 3 -n Gaussian -p 1 -r 1 -i $fileIn -o $T1path/${configs_T1_denoised}.nii.gz"
			else
				cmd="susan $T1path/${configs_T1} 56.5007996 3 3 1 0 $T1path/${configs_T1_denoised}"
			fi			
			log $cmd
			eval $cmd 
		fi 

		##### FSL ANAT ######
		if ${flags_T1_anat}; then

			# strongbias should be more appropriate for multi-channel coils on 3T scanners.        	
			if [ ${configs_T1_bias} -eq "0" ]; then
				T1bias="--nobias"
			elif [ ${configs_T1_bias} -eq "1" ]; then
				T1bias="--weakbias"
			else 
				T1bias=" "
			fi

			# add nocrop option if registration fails	
			if [ ${configs_T1_crop} -eq "0" ]; then
				T1crop="--nocrop"
			else 
				T1crop=" "
			fi


			T1args="${T1bias} ${T1crop}"

			if [[ -d "${T1path}/${configs_T1_denoised}.anat" ]]; then
				cmd="rm -fr ${T1path}/${configs_T1_denoised}.anat"
				log $cmd
				eval $cmd 
			fi

			if [[ -e "$T1path/${configs_T1_denoised}.nii.gz" ]]; then
				cmd="fsl_anat --noreg --nononlinreg --noseg ${T1args} -i ${T1path}/${configs_T1_denoised}.nii.gz"
				log ${cmd}
				eval ${cmd}
			else
				log "$T1path/${configs_T1_denoised}.nii.gz not found"
				exit 1
			fi 

			if [[ -e "${T1path}/${configs_T1_denoised}.anat/T1_biascorr.nii.gz" ]]; then
				cmd="cp ${T1path}/${configs_T1_denoised}.anat/T1_biascorr.nii.gz ${T1path}/T1_fov_denoised.nii.gz"
				log $cmd
				eval $cmd 
				cmd="gunzip ${T1path}/T1_fov_denoised.nii.gz"
				log $cmd
				eval $cmd 

				if [[ $? != 0 ]]; then
					echo 'FSL_ANAT NOT COMPLETED'
				fi
			else
				log "${T1path}/${configs_T1_denoised}.anat/T1_biascorr.nii.gz not found"
				exit 1	
			fi 
		fi 

		##### T1 BET ######
		
		if ${flags_T1_bet}; then

			log "BET Brain Extraction and Masking"

			fileIn="$T1path/T1_fov_denoised.nii"
			fileOutroot="$T1path/T1_"

			if [[ ${configs_antsTemplate} == "MICCAI" ]]; then

				log "${configs_antsTemplate} brain mask template selected"

				fileTemplate="${pathBrainmaskTemplates}/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0.nii.gz"
				fileProbability="${pathBrainmaskTemplates}/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumProbabilityMask.nii.gz"

			elif [[ ${configs_antsTemplate} == "NKI" ]]; then

				log "${configs_antsTemplate} brain mask template selected"

				fileTemplate="${pathBrainmaskTemplates}/NKI/T_template.nii.gz"
				fileProbability="${pathBrainmaskTemplates}/NKI/T_template_BrainCerebellumProbabilityMask.nii.gz"

			elif [[ ${configs_antsTemplate} == "bet" ]]; then

				log "${configs_antsTemplate} Using bet -f and -g inputs to perform fsl bet with -B option"

			else

				log "Unknown brain mask template selection: ${configs_antsTemplate}. Exiting..."

			fi 

			if [[ -e "${fileIn}" ]]; then
				fileIn2="$T1path/T1_brain_mask.nii.gz"
				fileOut="$T1path/T1_brain.nii.gz"

				if [[ ${configs_antsTemplate} == "bet" ]]; then
					cmd="bet ${fileIn} ${fileOut} \
					-B -m -f ${configs_T1_A_betF} -g ${configs_T1_A_betG}"
					log $cmd
					eval $cmd 
					out=$?
				else 
					antsBrainExtraction="$( which antsBrainExtraction.sh )"
					log "antsBrainExtraction path is $antsBrainExtraction"

					ANTSlog="$T1path/ants_bet.log"
					cmd="${antsBrainExtraction} -d 3 -a ${fileIn} \
					-e ${fileTemplate} \
					-m ${fileProbability} \
					-o ${fileOutroot} > ${ANTSlog}"
					log $cmd
					eval $cmd 					

					cmd="mv $T1path/T1_BrainExtractionMask.nii.gz ${fileIn2}"
					log $cmd
					eval $cmd 
					cmd="mv $T1path/T1_BrainExtractionBrain.nii.gz ${fileOut}"
					log $cmd
					eval $cmd 					
					out=$?
				fi 

				fileOut2="$T1path/T1_brain_mask_filled.nii.gz"

				if [[ $out == 0 ]] && [[ -e ${fileIn2} ]]; then
					#fill holes in the brain mask
					cmd="fslmaths ${fileIn2} -fillh ${fileOut2}"
					log $cmd
					eval $cmd	
					out=$?
					if [[ $out == 0 ]] && [[ -e ${fileOut2} ]]; then
						log "BET completed"
					else
						log "WARNING ${fileOut2} not created. Exiting... "
						exit 1					
					fi
				else
					log "WARNING ${fileIn2} not found. Exiting... "
					exit 1					
				fi
			else
				log "WARNING ${fileIn} not found. Exiting... "
				exit 1					
			fi

		fi

		##### T1 Brain Re-Extract ######
		if ${flags_T1_re_extract}; then
			fileIn="$T1path/T1_fov_denoised.nii"
			fileMask="$T1path/T1_brain_mask_filled.nii.gz"
			fileOut="$T1path/T1_brain.nii.gz"

			if [[ -e "$fileIn" ]] && [[ -e "$fileMask" ]]; then
				cmd="fslmaths ${fileIn} -mul ${fileMask} ${fileOut}"
				log $cmd
				eval $cmd
				out=$?
				if [[ $out == 0 ]] && [[ -e ${fileOut} ]]; then
					log "${fileOut} created"
				else
					log "WARNING ${fileOut} not created. Exiting... "
					exit 1					
				fi

			fi
		fi

	else
		msg="WARNING T1 directory is empty; skipping subject $SUBJ"
		log $msg
		exit 1
	fi
else
	msg="WARNING $T1path/${configs_dcmFolder} directory doesn't exist; skipping T1_prepare_A for subject $SUBJ"
	log $msg
	exit 1
fi 
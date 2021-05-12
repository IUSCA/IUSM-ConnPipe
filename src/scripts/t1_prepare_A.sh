
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
	if [[ "$(ls -A ${T1path}/${configs_dcmFolder})" ]]; then 

        log "T1_PREPARE_A"

		##### DICOM 2 nifti ######
		if ${flags_T1_dcm2niix}; then
			log "###### DICOM 2 nifti ######" 
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
					log "Using cropped field-of-view output of dcm2niix"
					cmd="gzip -f $T1path/${configs_T1}_Crop_1.nii"
					log $cmd
					eval $cmd 
					cmd="mv $T1path/${configs_T1}_Crop_1.nii.gz $T1path/${configs_T1}.nii.gz"
					log $cmd
					eval $cmd 
				else
					cmd="gzip -f $T1path/${configs_T1}_orig.nii"
					log $cmd
					eval $cmd
					cmd="mv $T1path/${configs_T1}_orig.nii.gz $T1path/${configs_T1}.nii.gz"
					log $cmd
					eval $cmd
				fi
			fi			
		fi


		##### T1 denoiser ######
		file4fslanat="$T1path/${configs_fslanat}"
		fileIn="$T1path/${configs_T1}.nii.gz"

		if [[ "${configs_fslanat}" == "T1_denoised_ANTS" ]]; then 

			log "-------- Denoising T1 WITH ANTS ---------"
			cmd="DenoiseImage -v -d 3 -n Gaussian -p 1 -r 1 -i ${fileIn} -o ${file4fslanat}.nii.gz"
			log $cmd
			eval $cmd
		elif [[ "${configs_fslanat}" == "T1_denoised_SUSAN" ]]; then

			file4fslanat="$T1path/${configs_fslanat}"
			log "-------- Denoising T1 WITH SUSAN --------"
			cmd="susan $T1path/${configs_T1} 56.5007996 3 3 1 0 ${file4fslanat}"
			log $cmd
			eval $cmd
		else
			log "-------- WARNING - Skipping T1 Denoising --------"
			echo "file4fslanat is ${file4fslanat}"
		fi

		##### FSL ANAT ######
		if ${flags_T1_anat}; then
			log "********** FSL ANAT ***********"

			# strongbias should be more appropriate for multi-channel coils on 3T scanners.        	
			if [ ${configs_T1_bias} -eq "0" ]; then
				T1bias="--nobias"
			elif [ ${configs_T1_bias} -eq "1" ]; then
				T1bias="--weakbias"
			else 
				T1bias=" "
			fi
			log "T1bias is ${T1bias}"

			# add nocrop option if registration fails	
			if [ ${configs_T1_crop} -eq "0" ]; then
				T1crop="--nocrop"
			else 
				T1crop=" "
			fi
			
			log "T1crop is ${T1crop}"

			T1args="${T1bias} ${T1crop}"

			if [[ -d "${file4fslanat}.anat" ]]; then
				cmd="rm -fr ${file4fslanat}.anat"
				log $cmd
				eval $cmd 
			fi

			if [[ -e "${file4fslanat}.nii.gz" ]]; then
				log "Running fsl_anat on ${file4fslanat}.nii.gz"
				cmd="fsl_anat --noreg --nononlinreg --noseg ${T1args} -i ${file4fslanat}.nii.gz"
				log ${cmd}
				eval ${cmd}
			else
				log "${file4fslanat}.nii.gz not found"
				exit 1
			fi 

			if [[ -e "${file4fslanat}.anat/T1_biascorr.nii.gz" ]]; then
				cmd="cp ${file4fslanat}.anat/T1_biascorr.nii.gz ${T1path}/T1_fov_denoised.nii.gz"
				log $cmd
				eval $cmd 
				cmd="gunzip ${T1path}/T1_fov_denoised.nii.gz"
				log $cmd
				eval $cmd 

				if [[ $? != 0 ]]; then
					echo 'FSL_ANAT NOT COMPLETED'
				fi
			else
				log "${file4fslanat}.anat/T1_biascorr.nii.gz not found"
				exit 1	
			fi 
		fi 

		##### T1 Brain Extraction and Masking ######
		
		if ${flags_T1_extract_and_mask}; then

			log "Brain Extraction and Masking"

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

			elif [[ ${configs_antsTemplate} == "IXI" ]]; then

				log "${configs_antsTemplate} brain mask template selected"

				fileTemplate="${pathBrainmaskTemplates}/IXI/T_template0.nii.gz"
				fileProbability="${pathBrainmaskTemplates}/IXI/T_template_BrainCerebellumProbabilityMask.nii.gz"


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

					## For QC purposes, we run bet anyway, to compare the bet mask with the one from ANTS
					
					fileOut_bet="$T1path/T1_brain_betQC.nii.gz"
					log "QC - bet will be run anyway for QC purposes - output is saved as ${fileOut_bet}"

					cmd="bet ${fileIn} ${fileOut_bet} \
					-B -m -f ${configs_T1_A_betF} -g ${configs_T1_A_betG}"
					log $cmd
					eval $cmd 
					qc_out=$?

					bet_mask="$T1path/T1_brain_betQC_mask.nii.gz"

					if [[ -e ${bet_mask} ]]; then

						overlap_mask="$T1path/T1_overlap_mask.nii.gz"
						qc "Computing the overlap between ANTS and bet brain masks"
						## Find the overlap between the two masks - BET vs ANTS and compute the volume
						cmd="fslmaths ${bet_mask} -mul ${fileIn2} -bin ${overlap_mask}"
						log "$cmd"
						eval $cmd

						# COmpute the volume of the overlap
						cmd="fslstats ${overlap_mask} -V"
						log "$cmd"
						out=`$cmd`
						qc "fslstats - Volume of overlap between ANTS and BET mask is $out"
						overlap_vol=`echo $out | awk -F' ' '{ print $2}'`

						# Compute the volume of the ANTS mask 
						cmd="fslstats ${fileIn2} -V"
						log "$cmd"
						out=`$cmd`
						qc "fslstats - Volume of ANTS mask is $out"
						ANTS_vol=`echo $out | awk -F' ' '{ print $2}'`		

						# Compute the proportion of the ANTS mask that is in the overlap
						match=$(bc <<< "scale=2 ; ${overlap_vol} / ${ANTS_vol}")	
						qc "Proportion of the ANTS mask that overlaps with BET mask is ${match}"	

						if (( $(echo "$match < ${config_brainmask_overlap_thr}" |bc -l) )); then
							qc "WARNING the mismatch between the ANTS brain_mask and bet brain_mask is greater than 80%"
							qc "QC is highly recommended. You may compare both masks with FSLeyes"
							qc "ANTS mask is ${fileIn2}"
							qc "BET mask is ${bet_mask}"
							qc "The intersection of the masks is ${overlap_mask}"
						fi 
						

					else
						log "WARNING: BET mask not generated.. skipping brain extraction QC"
						log "WARNING: We recommend doing a visual inspection of the brain mask" 
					fi

				fi 

				fileOut2="$T1path/T1_brain_mask_filled.nii.gz"

				if [[ -e ${fileIn2} ]]; then
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

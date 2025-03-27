
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

# Load packages/modules
#===========================================================================
module load ${fsl} 
module load ${ants}

# fsl607 hpc module has python3.11 contain in it.
#if ${flag_HPC_modules}; then
#    echo "Loading HPC native python"
#    module load ${HPC_python}
#fi 

# If FSL is not in the path, exit now
if [[ -n "${FSLDIR}" ]]; then
    echo "FSLDIR is ${FSLDIR}"
else
    echo -e "\033[33m#  ERROR. FSLDIR is not set. Exiting \033[0m"
    exit 1
fi

py_ver=$(python --version)
echo "****** ${py_ver} ******"
py_which=$(which python)
echo "****** ${py_which} ******"

###############################################################################

bidsT1="${SUBJ}_${SESS}_*T1w.nii.gz"
found_file=$(find "$T1path_raw" -type f -name "$bidsT1")

if [ -n "$found_file" ]; then

	bidsT1="${found_file}"
	log --no-datetime "T1 file to be processed: ${bidsT1}"

else
	echo "${bidsT1} T1 file not found in ${$T1path_raw}."
	exit 1
fi


##### T1 denoiser ######
file4fslanat="$T1path/${configs_fslanat}"

if ${flags_T1_applyDenoising}; then

	##### Apply fsl's robustfov ########
	if ${flags_T1_robustfov}; then

		log --no-datetime "Applying fsl's robustfov"

		T1filename=$(basename ${bidsT1})
		T1fov="${T1filename%%.*}_fov.nii.gz"

		cmd="robustfov -i ${bidsT1} -r $T1path/${T1fov}"
		log $cmd
		eval $cmd

		bidsT1=$T1path/${T1fov}
		log --no-datetime "New T1 file to be processed is ${bidsT1}"
	fi

	log --no-datetime " -------- Denoising T1 -------- "
	
	if [[ "${configs_fslanat}" == "T1_denoised_ANTS" ]]; then 

		log "-------- Denoising T1 WITH ANTS ---------"
		cmd="DenoiseImage -v -d 3 -n Gaussian -p 1 -r 1 -i ${bidsT1} -o ${file4fslanat}.nii.gz"
		log $cmd
		eval $cmd 2>&1 | tee -a ${logfile_name}.log
	elif [[ "${configs_fslanat}" == "T1_denoised_SUSAN" ]]; then

		log "-------- Denoising T1 WITH SUSAN --------"
		cmd="susan ${bidsT1} 56.5007996 3 3 1 0 ${file4fslanat}"
		log --no-datetime $cmd
		eval $cmd 2>&1 | tee -a ${logfile_name}.log
	else
		log "-------- WARNING - Skipping T1 Denoising --------"
		cmd="cp ${bidsT1} ${file4fslanat}.nii.gz"
		log --no-datetime $cmd 
		eval $cmd 
		echo "file4fslanat is ${file4fslanat}.nii.gz"

	fi
fi

##### FSL ANAT ######
if ${flags_T1_anat}; then
	log " ---------- FSL ANAT ---------- "

	# strongbias should be more appropriate for multi-channel coils on 3T scanners.        	
	if [ ${configs_T1_bias} -eq "0" ]; then
		T1bias="--nobias"
	elif [ ${configs_T1_bias} -eq "1" ]; then
		T1bias="--weakbias"
	elif [ ${configs_T1_bias} -eq "2" ]; then
		T1bias="--strongbias"
	else 
		T1bias=""
	fi

	if [ -z "$T1bias" ]; then
    	log --no-datetime "T1bias is unspecified. --weakbias (FSL default) is used"
	else
    	log --no-datetime "T1bias is ${T1bias}"
	fi

	# add nocrop option if registration fails	
	if [ ${configs_T1_crop} -eq "0" ]; then
		T1crop="--nocrop"
	else 
		T1crop=""
	fi

	if [ -z "$T1crop" ]; then
		log --no-datetime "T1crop: robustfov cropping will be done."
	else
		log --no-datetime "T1crop is ${T1crop}"
	fi

	T1args="${T1bias} ${T1crop}"

	if [[ -d "${file4fslanat}.anat" ]]; then
		cmd="rm -fr ${file4fslanat}.anat"
		log --no-datetime $cmd
		eval $cmd 
	fi

	if [[ -e "${file4fslanat}.nii.gz" ]]; then
		log --no-datetime "Running fsl_anat on ${file4fslanat}.nii.gz"
		cmd="fsl_anat --noreg --nononlinreg --noseg ${T1args} -i ${file4fslanat}.nii.gz"
		log ${cmd}
		eval ${cmd} 2>&1 | tee -a ${logfile_name}.log
	else
		log "${file4fslanat}.nii.gz not found"
		exit 1
	fi 

	if [[ -e "${file4fslanat}.anat/T1_biascorr.nii.gz" ]]; then
		cmd="cp ${file4fslanat}.anat/T1_biascorr.nii.gz ${T1path}/T1_fov_denoised.nii.gz"
		log $cmd
		eval $cmd 
		cmd="gunzip -f ${T1path}/T1_fov_denoised.nii.gz"
		log --no-datetime $cmd
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

	T1denoised="$T1path/T1_fov_denoised.nii"
	fileOutroot="$T1path/T1_"

	if [[ ${configs_antsTemplate} == "MICCAI" ]]; then

		log --no-datetime "${configs_antsTemplate} brain mask template selected"

		fileTemplate="${pathBrainmaskTemplates}/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0.nii.gz"
		fileProbability="${pathBrainmaskTemplates}/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumProbabilityMask.nii.gz"

	elif [[ ${configs_antsTemplate} == "NKI" ]]; then

		log --no-datetime "${configs_antsTemplate} brain mask template selected"

		fileTemplate="${pathBrainmaskTemplates}/NKI/T_template.nii.gz"
		fileProbability="${pathBrainmaskTemplates}/NKI/T_template_BrainCerebellumProbabilityMask.nii.gz"

	elif [[ ${configs_antsTemplate} == "IXI" ]]; then

		log --no-datetime "${configs_antsTemplate} brain mask template selected"

		fileTemplate="${pathBrainmaskTemplates}/IXI/T_template0.nii.gz"
		fileProbability="${pathBrainmaskTemplates}/IXI/T_template_BrainCerebellumProbabilityMask.nii.gz"

	elif [[ ${configs_antsTemplate} == "KBASE" ]]; then

		log --no-datetime "${configs_antsTemplate} brain mask template selected"

		fileTemplate="${pathBrainmaskTemplates}/KBASE/t1template0.nii.gz"
		fileProbability="${pathBrainmaskTemplates}/KBASE/t1template0_probabilityMask.nii.gz"


	elif [[ ${configs_antsTemplate} == "bet" ]]; then

		log --no-datetime "${configs_antsTemplate} Using bet -f and -g inputs to perform fsl bet with -B option"

	else

		log "Unknown brain mask template selection: ${configs_antsTemplate}. Exiting..."

	fi 

	if [[ -e "${T1denoised}" ]]; then
		
		T1brain="$T1path/T1_brain.nii.gz"
		T1brainmask="$T1path/T1_brain_mask.nii.gz"
		T1brainmask_filled="$T1path/T1_brain_mask_filled.nii.gz"

		if [[ ${configs_antsTemplate} == "bet" ]]; then
			cmd="bet ${T1denoised} ${T1brain} \
			-B -m -f ${configs_T1_A_betF} -g ${configs_T1_A_betG}"
			log --no-datetime $cmd
			eval $cmd 
		else 
			antsBrainExtraction="$( which antsBrainExtraction.sh )"
			log --no-datetime "antsBrainExtraction path is $antsBrainExtraction"

			ANTSlog="$T1path/ants_bet.log"
			cmd="${antsBrainExtraction} -d 3 -a ${T1denoised} \
			-e ${fileTemplate} \
			-m ${fileProbability} \
			-o ${fileOutroot}"
			log --no-datetime $cmd
			eval $cmd 2>&1 | tee -a ${ANTSlog}		

			cmd="mv $T1path/T1_BrainExtractionBrain.nii.gz ${T1brain}"
			log --no-datetime $cmd
			eval $cmd 
			cmd="mv $T1path/T1_BrainExtractionMask.nii.gz ${T1brainmask}"
			log --no-datetime $cmd
			eval $cmd 
					
		fi

		if [[ -e ${T1brainmask} ]]; then
			#fill holes in the brain mask
			cmd="fslmaths ${T1brainmask} -fillh ${T1brainmask_filled}"
			log $cmd
			eval $cmd
		else
			log "WARNING ${T1brainmask} not found. Exiting... "
			exit 1					
		fi

		if [ -n "${config_brainmask_overlap_thr}" ] && [ ${configs_antsTemplate} != "bet" ]; then
			## For QC purposes, we run bet anyway, to compare the bet mask with the one from ANTS

			T1brain_betQC="$T1path/T1_brain_betQC.nii.gz"
			T1brainmask_betQC="$T1path/T1_brain_betQC_mask.nii.gz"
			T1brainmask_filled_betQC="$T1path/T1_brain_betQC_mask_filled.nii.gz"

			log --no-datetime "QC - bet will be run anyway for QC purposes - output is saved as ${T1brain_betQC}"

			cmd="bet ${T1denoised} ${T1brain_betQC} \
			-B -m -f ${configs_T1_A_betF} -g ${configs_T1_A_betG}"
			log $cmd
			eval $cmd 

			#fill holes in the brain mask
			cmd="fslmaths ${T1brainmask_betQC} -fillh ${T1brainmask_filled_betQC}"
			log $cmd
			eval $cmd
			

			if [[ -e ${T1brainmask_betQC} ]]; then

				overlap_mask="$T1path/T1_brain_overlap_mask.nii.gz"
				qc "Computing the overlap between ANTS and bet filled brain masks"
				## Find the overlap between the two masks - BET vs ANTS and compute the volume
				cmd="fslmaths ${T1brainmask_filled_betQC} -mul ${T1brainmask_filled} -bin ${overlap_mask}"
				log --no-datetime "$cmd"
				eval $cmd

				# COmpute the volume of the overlap
				cmd="fslstats ${overlap_mask} -V"
				log "$cmd"
				out=`$cmd`
				qc "fslstats - Volume of overlap between ANTS and BET mask is $out"
				overlap_vol=`echo $out | awk -F' ' '{ print $2}'`

				# Compute the volume of the ANTS mask 
				cmd="fslstats ${T1brainmask_filled} -V"
				log "$cmd"
				out=`$cmd`
				qc "fslstats - Volume of ANTS mask is $out"
				ANTS_vol=`echo $out | awk -F' ' '{ print $2}'`		

				# Compute the proportion of the ANTS mask that is in the overlap
				match=$(bc <<< "scale=2 ; ${overlap_vol} / ${ANTS_vol}")	
				qc "Proportion of the ANTS mask that overlaps with BET mask is ${match}"	

				if (( $(echo "$match < ${config_brainmask_overlap_thr}" |bc -l) )); then
					qc "WARNING the mismatch between ANTS and BET does not meet the specified overalp threashold of ${config_brainmask_overlap_thr}"
					qc --no-datetime "QC is highly recommended. You may compare both masks with FSLeyes"
					qc --no-datetime "ANTS mask is ${T1brainmask}"
					qc --no-datetime "BET mask is ${T1brainmask_betQC}"
					qc --no-datetime "The intersection of the masks is ${overlap_mask}"
				fi 		

			else
				log "WARNING: BET mask not generated.. skipping brain extraction QC"
				log --no-datetime "WARNING: We recommend doing a visual inspection of the brain mask." 
			fi
		fi
	else
		log "WARNING ${T1denoised} not found. Exiting... "
		exit 1					
	fi
fi


if ${config_use_overlap_brainmask}; then 

	overlap_mask="$T1path/T1_brain_overlap_mask.nii.gz"
	T1brain="$T1path/T1_brain.nii.gz"
	T1brainmask="$T1path/T1_brain_mask.nii.gz"
	T1brainmask_filled="$T1path/T1_brain_mask_filled.nii.gz"

	if [[ -e ${overlap_mask} ]]; then
		# rename files
		log --no-datetime "WARNING: overlap brain mask will be renamed"

		cmd="mv ${T1brain} $T1path/T1_BrainExtractionBrain.nii.gz "
		log --no-datetime $cmd
		eval $cmd 
		cmd="mv ${T1brainmask} $T1path/T1_BrainExtractionMask.nii.gz"
		log --no-datetime $cmd
		eval $cmd 
		cmd="mv ${T1brainmask_filled} $T1path/T1_BrainExtractionMask_filled.nii.gz "
		log --no-datetime $cmd
		eval $cmd 

		cmd="mv ${overlap_mask} ${T1brainmask}"
		log --no-datetime $cmd
		eval $cmd		

		#fill holes in the brain mask, just in case...
		cmd="fslmaths ${T1brainmask} -fillh ${T1brainmask_filled}"
		log $cmd
		eval $cmd	

		qc "WARNING: overlap mask has been set as the default mask"


	else
		log "WARNING ${overlap_mask} not found. Exiting... "
		log --no-datetime "Check that mask overlap calculations have been performed:"
		log --no-datetime "-- check that the config config_brainmask_overlap_thr is set to a value < 1"
		exit 1					
	fi

fi 

##### T1 Brain Re-Extract ######
if ${flags_T1_re_extract}; then
	T1denoised="$T1path/T1_fov_denoised.nii"
	T1brainmask_filled="$T1path/T1_brain_mask_filled.nii.gz"
	T1brain="$T1path/T1_brain.nii.gz"

	if [[ -e "$T1denoised" ]] && [[ -e "$T1brainmask_filled" ]]; then
		cmd="fslmaths ${T1denoised} -mul ${T1brainmask_filled} ${T1brain}"
		log "$cmd"
		eval $cmd
		out=$?
		if [[ $out == 0 ]] && [[ -e ${T1brain} ]]; then
			log --no-datetime "${T1brain} created"
		else
			log "WARNING ${T1brain} not created. Exiting... "
			exit 1					
		fi

	fi
fi

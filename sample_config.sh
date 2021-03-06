#!/bin/bash


################################################################################
################################################################################
## GLOBALS & dependencies

# source bash funcs
source ${EXEDIR}/src/func/bash_funcs.sh

## pip install pydicom --user

################################################################################
####################### DEFINE SUBJECTS TO RUN  ###################################

if ${runAll}; then
	find ${path2data} -maxdepth 1 -mindepth 1 -type d -printf '%f\n' \
	| sort > ${path2data}/${subj2run}	
fi 

################################################################################
#####################  SET UP DIRECTORY STRUCTURE  #############################

# USER INSTRUCTIONS - The following diagrapm is a sample directory tree for a single subject.
# Following that are configs you can use to set your own names if different
# from sample structure.

# SUBJECT1 -- T1 -- DICOMS
#          |
#          -- EPI(#) -- DICOMS (May have multiple EPI scans)
#          |         
#          |                        (SPIN-ECHO)       (GRADIENT ECHO)
#          -- UNWARP1 -- SEFM_AP_DICOMS (OR) GREFM_MAG_DICOMS
#          |         
#          |          -- SEFM_PA_DICOMS (OR) GREFM_PHASE_DICOMS
#          |         
#          |                       (SPIN-ECHO)       (GRADIENT ECHO)
#          -- UNWARP2 -- SEFM_AP_DICOMS (OR) GREFM_MAG_DICOMS
#          |          
#          |          -- SEFM_PA_DICOMS (OR) GREFM_PHASE_DICOMS
#          |
#          -- DWI -- DICOMS
#                 |
#                 -- UNWARP -- B0_PA_DCM

export configs_T1="T1"
export configs_epiFolder="EPI"

export configs_sefmFolder="UNWARP1" # Reserved for Field Mapping series
	export configs_APdcm="SEFM_AP_DICOMS" # Spin Echo A-P
	export configs_PAdcm="SEFM_PA_DICOMS" # Spin Echo P-A

export configs_grefmFolder="GREFM"  # Reserved for Field Mapping series
	export configs_GREmagdcm="MAG_DICOMS" # Gradient echo FM magnitude series
	export configs_GREphasedcm="PHASE_DICOMS" # Gradient echo FM phase map series

export configs_dcmFolder="DICOMS"
export configs_dcmFiles="dcm" # specify Dicom file extension
export configs_niiFiles="nii" # Nifti-1 file extension

export configs_DWI="DWI"
    export configs_unwarpFolder="UNWARP"
        export configs_dcmPA="B0_PA_DCM" #b0 opposite phase encoding
## USER: select only one option below (single phase or two phase)
### Single phase ###
	# export configs_DWI_dcmFolder="DICOMS"
### Two phase###
#Allow two DICOM directories (e.g., AP/PA, LR/RL,...).Both phase directions must exist  
	export configs_DWI_dcmFolder1="DICOMS1" # Specify first phase direction (e.g., AP)
	export configs_DWI_dcmFolder2="DICOMS2" # Specify reverse phase data direction (e.g., PA)


################################################################################
################################ TEMPLATES #####################################

export pathFSLstandard="${FSLDIR}/data/standard"

## path to Supplementary Materials (SM)

## FOR IUSM USERS ONLY - DURING DEVELOPMENT PHASE, PLEASE USE THIS "pathSM" AS THE 
## SUPPLEMENTARY MATERIALS PATH. THIS WILL EVENTUALLY LIVE IN A REPOSITORY 
export pathSM="/N/project/ConnPipelineSM"
export pathMNItmplates="${pathSM}/MNI_templates"
export pathBrainmaskTemplates="${pathSM}/brainmask_templates"
export pathParcellations="${pathSM}/Parcellations"
export PYpck="${pathSM}/python-pkgs"


################################################################################
################################ PARCELLATIONS #################################

# required parc
export PARC0="CSFvent"
export PARC0dir="${pathMNItmplates}/MNI152_T1_1mm_VentricleMask.nii.gz"
export PARC0pcort=0;
export PARC0pnodal=0;
export PARC0psubcortonly=0;

# required
# Schaefer parcellation of yeo17 into 200 nodes
export PARC1="schaefer200_yeo17"
export PARC1dir="Schaefer2018_200Parcels_17Networks_order_FSLMNI152_1mm"
export PARC1pcort=1;
export PARC1pnodal=1;
export PARC1psubcortonly=0;

# Schaefer parcellation of yeo17 into 300 nodes
# optional
export PARC2="schaefer300_yeo17"
export PARC2dir="Schaefer2018_300Parcels_17Networks_order_FSLMNI152_1mm"
export PARC2pcort=1;
export PARC2pnodal=1;
export PARC2psubcortonly=0;

# optional
export PARC3="yeo17"
export PARC3dir="yeo17_MNI152"
export PARC3pcort=1;
export PARC3pnodal=0;
export PARC3psubcortonly=0;

# optional
export PARC4="tian_subcortical_S2"
export PARC4dir="Tian_Subcortex_S2_3T_FSLMNI152_1mm"
export PARC4pcort=0;
export PARC4pnodal=1;
export PARC4psubcortonly=1;



## USER INSTRUCTIONS - SET THE NUMBER OF PARCELLATIONS THAT YOU WANT TO USE
## FROM THE OPTIONS LISTED ABOVE. YOU MAY ADD YOUR OWN PARCELLATIONS BY FOLLOWING
## THE NAMING FORMAT. NOTE THAT PARCELLATIONS ARE RUN IN THE ORDER IN WHICH THEY ARE 
## LISTED ABOVE. FOR EXAMPLE IF numParcs is set to 1, ONLY CSF AND PARC1="shen_278"
## WILL BE USED
export numParcs=4  # CSF doesn't count; numParcs cannot be less than 1. Schaefer is the defailt parc


################################################################################
############################# T1_PREPARE_A #####################################

## USER INSTRUCTIONS - SET THIS FLAG TO "false" IF YOU WANT TO SKIP THIS SECTION
## ALL FLAGS ARE SET TO DEFAULT SETTINGS
export T1_PREPARE_A=false

if $T1_PREPARE_A; then

	export flags_T1_dcm2niix=false  # dicom to nifti conversion 
		export configs_T1_useCropped=false # use cropped field-of-view output of dcm2niix
		
	## T1 DENOISING IS PERFORMED AFTER DICOM TO NIFTI CONVERSION. 
	#### THE DENOISING FLAG IS ALSO USED IN T1_PREPARE_B SO IT IS SET AS A GLOBAL FALG, BELOW

	export flags_T1_anat=true # run FSL_anat
		export configs_T1_bias=0 # 0 = no; 1 = weak; 2 = strong
		export configs_T1_crop=0 # 0 = no; 1 = yes (lots already done by dcm2niix)

	export flags_T1_extract_and_mask=true # brain extraction and mask generation (only needed for double BET)
		export configs_antsTemplate="NKI"  # options are: ANTS (MICCAI, NKI, IXI) or bet
		export configs_T1_A_betF="0.3" # this are brain extraction parameters with FSL bet
		export configs_T1_A_betG="-0.1"  # see fsl bet help page for more details
		export config_brainmask_overlap_thr="0.90"  # this is the threshold to assess whether or not the ANTS and BET masks are similar 'ehough"'
		# USER if runnign ANTS, bet will be run anyway as a QC check for the brain maks.
		# QC output will be printed out in the QC file for each subject. 
	 
	export flags_T1_re_extract=true; # brain extraction with mask

fi 


# # Set denoising option
configs_T1_denoised="ANTS"  # OTHER OPTIONS ARE: "SUSAN" FSL'S SUSAN
# # =========================================================================================
# # USER INSTRUCTIONS - DON'T MODIFY THE FOLLOWING SECTION
# #===========================================================================================							#					 "NONE" FOR SKIPPING DENOISING
if [[ "${configs_T1_denoised}" == "ANTS" ]]; then 
	export configs_fslanat="T1_denoised_ANTS"
	echo "USING ANTS FOR DENOISING"
elif [[ "${configs_T1_denoised}" == "SUSAN" ]]; then
	export configs_fslanat="T1_denoised_SUSAN"
	echo "USING SUSAN FOR DENOISING"
elif [[ "${configs_T1_denoised}" == "NONE" ]]; then
	export configs_fslanat=${configs_T1}
	echo "SKIPPING DENOISING"
fi
# #===========================================================================================


################################################################################
############################# T1_PREPARE_B #####################################

## USER INSTRUCTIONS - SET THIS FLAG TO "false" IF YOU WANT TO SKIP THIS SECTION
## ALL FLAGS ARE SET TO DEFAULT SETTINGS
export T1_PREPARE_B=false 

if $T1_PREPARE_B; then

	# registration flags
	export flags_T1_reg2MNI=true
		export configs_T1_useExistingMats=false
		export configs_T1_useMNIbrain=true
		export configs_T1_fnirtSubSamp="4,4,2,1"
	# segmentation flags
	export flags_T1_seg=true		
		export configs_T1_segfastH="0.25"
		export configs_T1_masklowthr=1
		export configs_T1_flirtdof6cost="mutualinfo"
	# parcellation flags
	export flags_T1_parc=true
		export configs_T1_numDilReMask=3
		export configs_T1_addsubcort=true # add FSL subcortical to cortial parcellations 	
										  # but ONLY to nodal parcellation as individual regions
										  # To others add as a single subcortical network.
		export configs_T1_subcortUser=true   # false = default FSL; true = user-provided
											  # Name of user-provided subcortical parcellation (assumed to be found in ConnPipeSM folder)
											  # should be set in the desired parcellation name for index "N" with "psubcortonly=1"
	# =========================================================================================
	# USER INSTRUCTIONS - DON'T MODIFY THE FOLLOWING SECTION
	#===========================================================================================
		if ${configs_T1_useMNIbrain}; then
			export path2MNIref="${pathFSLstandard}/MNI152_T1_1mm_brain.nii.gz"
		else
			export path2MNIref="${pathFSLstandard}/MNI152_T1_1mm.nii.gz"
		fi
	#===========================================================================================
fi 


################################################################################
############################# fMRI_A #####################################

## USER INSTRUCTIONS - SET THIS FLAG TO "false" IF YOU WANT TO SKIP THIS SECTION
## ALL FLAGS ARE SET TO DEFAULT SETTINGS
export fMRI_A=true

if $fMRI_A; then

	export scanner="GE" #  SIEMENS or GE
	log "SCANNER ${scanner}"

	# # set number of EPI sessions/scans
	export configs_EPI_epiMin=1; # minimum scan index
	export configs_EPI_epiMax=4; # maximum scan index

	export flags_EPI_dcm2niix=false; # dicom import

	export flags_EPI_ReadHeaders=false; # obtain pertinent scan information

		export flags_EPI_UseJson=true; # obtain pertinent scan information through json files generated by dcm2niix

		# =========================================================================================
		# USER INSTRUCTIONS - DON'T MODIFY THE FOLLOWING SECTION
		#===========================================================================================
		if [[ ${scanner} == "SIEMENS" ]]; then
			export scanner_param_TR="RepetitionTime"  # "RepetitionTime" for Siemens; "tr" for GE
			export scanner_param_TE="EchoTime"  # "EchoTime" for Siemens; "te" for GE
			export scanner_param_FlipAngle="FlipAngle"  # "FlipAngle" for Siemens; "flip_angle" for GE
			export scanner_param_EffectiveEchoSpacing="EffectiveEchoSpacing"  # "EffectiveEchoSpacing" for Siemens; "effective_echo_spacing" for GE
			export scanner_param_BandwidthPerPixelPhaseEncode="BandwidthPerPixelPhaseEncode"  # "BandwidthPerPixelPhaseEncode" for Siemens; unknown for GE
			export scanner_param_slice_fractimes="SliceTiming"  # "SliceTiming" for Siemens; "slice_timing" for GE
			export scanner_param_TotalReadoutTime="TotalReadoutTime"
			export scammer_param_AcquisitionMatrix="AcquisitionMatrixPE"
			export scanner_param_PhaseEncodingDirection="PhaseEncodingDirection"
		elif [[ ${scanner} == "GE" ]]; then
			export scanner_param_TR="tr"  # "RepetitionTime" for Siemens; "tr" for GE
			export scanner_param_TE="te"  # "EchoTime" for Siemens; "te" for GE
			export scanner_param_FlipAngle="flip_angle"  # "FlipAngle" for Siemens; "flip_angle" for GE
			export scanner_param_EffectiveEchoSpacing="effective_echo_spacing"  # "EffectiveEchoSpacing" for Siemens; "effective_echo_spacing" for GE
			export scanner_param_BandwidthPerPixelPhaseEncode="pixel_bandwidth"  # "BandwidthPerPixelPhaseEncode" for Siemens; unknown for GE
			export scanner_param_slice_fractimes="slice_timing"  # "SliceTiming" for Siemens; "slice_timing" for GE
			export scanner_param_TotalReadoutTime="TotalReadoutTime"
			export scammer_param_AcquisitionMatrix="acquisition_matrix"
			export scanner_param_PhaseEncodingDirection="phase_encode_direction"
		fi
		#===========================================================================================

	##########################################################
	## User must select either SpinEchoUnwarp or GREFMUnwarp. 
	##########################################################
	export flags_EPI_SpinEchoUnwarp=false # Requires UNWARP directory and approporiate dicoms.
    	# # Allow multiple UNWARP directories (0: UNWARP; 1: UNWARP1, 2: UNWARP2) 
    	export configs_EPI_multiSEfieldmaps=true # false - single pair of SE fieldmaps within EPI folder
												  # true -  one or multiple UNWARP folders at the subject level (UNWARP1, UNWARP2,...)
			# set only if configs_EPI_multiSEfieldmaps=true:
			# specify number of UNWARP directories (0: UNWARP; 1: UNWARP1, 2: UNWARP2)
			export configs_EPI_SEindex=1
    	export configs_EPI_skipSEmap4EPI=1 # Skip SEmap calculation for EPInum > configs_EPI_skipGREmap4EPI
                ##  e.g.; 1 to skip redoing SEmap for EPIs 2-6; 5 to skip for EPI6

	# # SPIN ECHO PAIRS (A-P, P-A) Acquistion on the Prisma
		export configs_EPI_SEnumMaps=3; # Fallback Number of PAIRS of AP and PA field maps.
	# # Defaults to reading *.dcm/ima files in SE AP/PA folders

	# # topup (see www.mccauslanddenter.sc.edu/cml/tools/advanced-dti - Chris Rorden's description
		export flags_EPI_RunTopup=true # 1=Run topup (1st pass), 0=Do not rerun if previously completed. 

	# # Gradient recalled echo Field Map Acquisition
	export flags_EPI_GREFMUnwarp=false # Requires GREfieldmap directory and appropriate dicoms
    	
		export configs_use_DICOMS=false  # set to true if Extract TE1 and TE2 from the first image of Gradient Echo Magnitude Series
										 # set to false if gre_fieldmap_mag already generated (i.e. STANFORD data)	
										# if set to 'false', GREFMUnwarp code will look for a single Magnitude file and try to extract Mag1 and Mag2
										# or, it will look for Mag1 and Mag2
			export configs_extract_twoMags=true
			export configs_Mag_file="gre_fieldmap_mag"
				export configs_Mag1="gre_fieldmap_mag_0000.nii.gz"  #if Mag1 and Mag2 already exist, name them here
				export configs_Mag2="gre_fieldmap_mag_0001.nii.gz"
			export configs_Phase_file="gre_fieldmap_phasemap"
			
		export configs_convert2radss=true   # if fieldmap_phasemap is in Hz, then it must be converted to rads/s 
												# set to true for NANSTAN
		export configs_fsl_prepare_fieldmap=false
		
		export configs_EPI_skipGREmap4EPI=1 # Skip GREmap calculation for EPInum => configs_EPI_skipGREmap4EPI
                # 0 to ignore. 1 to skip redoing GREmap for EPIs 2-6

		export configs_EPI_GREbetf=0.5; # GRE-specific bet values. Do not change
		export configs_EPI_GREbetg=0;   # GRE-specific bet input. Change if needed 
		export configs_EPI_GREdespike=true # Perform FM despiking
		export configs_EPI_GREsmooth=3; # GRE phase map smoothing (Gaussian sigma, mm)
		# Do not use configs.EPI.EPIdwell. Use params.EPI.EffectiveEchoSpacing extracted from the json header
     	# export configs_EPI_EPIdwell = 0.000308; # Dwell time (sec) for the EPI to be unwarped 

	# =========================================================================================
	# USER INSTRUCTIONS - DON'T MODIFY THE FOLLOWING SECTION
	#===========================================================================================
	if ${flags_EPI_SpinEchoUnwarp} && ${flags_EPI_GREFMUnwarp}; then
		log "ERROR 	Please select one option only: Spin Echo Unwarp or Gradient Echo Unwarp. Exiting... "
		exit 1
	fi
	#===========================================================================================	

	export flags_EPI_SliceTimingCorr=false
		#export flags_EPI_UseUnwarped=true # Use unwarped EPI if both warped and unwarped are available.
		
		export configs_EPI_minTR=1.6
		export configs_EPI_UseTcustom=1;# 1: use header-extracted times (suggested)

	export flags_EPI_MotionCorr=false

	export flags_EPI_RegT1=false
		export configs_EPI_epibetF=0.3000;

	export flags_EPI_RegOthers=false 
		export configs_EPI_GMprobthr=0.2 # Threshold the GM probability image; change from 0.25 to 0.2 or 0.15										
		export configs_EPI_minVoxelsClust=8 # originally hardwired to 8

	export flags_EPI_IntNorm4D=false # Intensity normalization to global 4D mean of 1000

	########## MOTION AND OUTLIER CORRECTION ###############
	export flags_EPI_NuisanceReg=false
	## Nuisance Regressors. There are two options that user can select from:
	# 1) ICA-based denoising; WARNING: This will smooth your data.
	# 2) Head Motion Parameter Regression.  
	## If user sets flags_NuisanceReg_AROMA=true, then flags_NuisanceReg_HeadParam=false
	## If user sets flags_NuisanceReg_AROMA=false, then flags_NuisanceReg_HeadParam=true

		export flags_NuisanceReg_AROMA=true  

			
			if ${flags_NuisanceReg_AROMA}; then # if using ICA-AROMA
				## USER: by default, ICA_AROMA will estimate the dimensionality (i.e. num of independent components) for you; however, for higher multiband
				## factors with many time-points and high motion subjects, it may be useful for the user to set the dimensionality. THis can be done by
				## setting the desired number of componenets in the following config flag. Leave undefined for automatic estimation 
				export flag_AROMA_dim=

				# =========================================================================================
				# USER INSTRUCTIONS - DON'T MODIFY THE FOLLOWING SECTION
				#===========================================================================================
				nR="aroma" # set filename postfix for output image
				export flags_NuisanceReg_HeadParam=false
				
				# Use the ICA-AROMA package contained in the ConnPipe-SuppMaterials
				ICA_AROMA_path="${PYpck}/ICA-AROMA" 
				export run_ICA_AROMA="python ${ICA_AROMA_path}/ICA_AROMA.py"
				## UNCOMMENT FOLLOWING LINE **ONLY** IF USING HPC ica-aroma MODULE:
				# export run_ICA_AROMA="ICA_AROMA.py"

				if [[ -e "${pathFSLstandard}/MNI152_T1_2mm_brain.nii.gz" ]]; then
					fileMNI2mm="${pathFSLstandard}/MNI152_T1_2mm_brain.nii.gz"
				else
					fileMNI2mm="${pathMNItmplates}/MNI152_T1_2mm_brain.nii.gz"
				fi
				#===========================================================================================
			else   # if using Head Motion Parameters
				export flags_NuisanceReg_HeadParam=true
					
					export configs_EPI_numReg=12  # 12 (orig and deriv) or 24 (+sq of 12)
				# =========================================================================================
				# USER INSTRUCTIONS - DON'T MODIFY THE FOLLOWING SECTION
				#===========================================================================================					
					nR="hmp${configs_EPI_numReg}"   # set filename postfix for output image
					
					if [[ "${configs_EPI_numReg}" -ne 12 && "${configs_EPI_numReg}" -ne 24 ]]; then
						log "WARNING the variable config_EPI_numReg must have values '12' or '24'. \
							Please set the corect value in the config.sh file"
					fi		

				#===========================================================================================
			fi

	########## PHYSIOLOGICAL REGRESSORS ###############
	export flags_EPI_PhysiolReg=false  
	# Two options that the user can select from:
	# 1) flags_PhysiolReg_aCompCorr=true - aCompCorr; PCA based CSF and WM signal regression (up to 5 components)
	# 2) flags_PhysiolReg_aCompCorr=false - mean WM and CSF signal regression
		export flags_PhysiolReg_aCompCorr=true  

		if ${flags_PhysiolReg_aCompCorr}; then  ### if using aCompCorr
			export flags_PhysiolReg_WM_CSF=false
			export configs_EPI_numPC=5; # 1-5; the maximum and recommended number is 5 
										  # set to 6 to include all 
				if [[ "${configs_EPI_numPC}" -ge 0 && "${configs_EPI_numPC}" -le 5 ]]; then
					nR="${nR}_pca${configs_EPI_numPC}"
				elif [[ "${configs_EPI_numPC}" -ge 5 ]]; then
					nR="${nR}_pca"
				fi 
		else
			export flags_PhysiolReg_WM_CSF=true  ### if using mean WM and CSF signal reg
				
				export configs_EPI_numPhys=8; # 2-orig; 4-orig+deriv; 8-orig+deriv+sq
					nR="${nR}_mPhys${configs_EPI_numPhys}"

					if [[ "${configs_EPI_numPhys}" -ne "2" \
					&& "${configs_EPI_numPhys}" -ne 4 \
					&& "${configs_EPI_numPhys}" -ne 8 ]]; then
						log "WARNING the variable configs_EPI_numPhys must have values '2', '4' or '8'. \
							Please set the corect value in the config.sh file"
					fi	
		fi

		if ${flags_NuisanceReg_AROMA}; then  
			export configs_EPI_resting_file='/AROMA/AROMA-output/denoised_func_data_nonaggr.nii.gz' 
			if ${flags_PhysiolReg_aCompCorr}; then  
				export regPath="AROMA/aCompCorr"    
			elif ${flags_PhysiolReg_WM_CSF}; then
				export regPath="AROMA/PhysReg"
			fi          
		elif ${flags_NuisanceReg_HeadParam}; then 
			export configs_EPI_resting_file='/4_epi.nii.gz' 
			if ${flags_PhysiolReg_aCompCorr}; then  
				log "PhysiolReg - Combining aCompCorr with HMP regressors"
				export regPath="HMPreg/aCompCorr"    
			elif ${flags_PhysiolReg_WM_CSF}; then
				log "PhysiolReg - Combining Mean CSF & WM signal with HMP regressors"
				export regPath="HMPreg/PhysReg"
			fi          
		fi

	# Optional denoising
	export flags_EPI_regressOthers=false

		export flags_EPI_GS=true # global signal regression 
			
			export configs_EPI_numGS=4 # 1-orig; 2-orig+deriv; 4-orig+deriv+sq
			
			if ${flags_EPI_GS}; then
				nR="${nR}_Gs${configs_EPI_numGS}"
			fi 
			
		export configs_EPI_DCThighpass=false  # Perform highpass filtering within regression. 
			
			export configs_EPI_dctfMin=0.009  # Specify level of high-pass filtering in Hz, 
										      # i.e. the lowest frequency signals that will be retained 
										      # The appropriate number (k) of DCT bases will be determined as follows:
										      # k = fMin * 2 * TR * numTimePoints 
									
			if ${configs_EPI_DCThighpass}; then
				# if [[ "${configs_EPI_numDCT}" > 0 ]]; then
				# nR="${nR}_DCT${configs_EPI_numDCT}"
				nR="${nR}_DCT"
			fi

		export flags_EPI_DVARS=false 

			if ${flags_EPI_DVARS}; then
				nR="${nR}_DVARS"
			fi

	export flags_EPI_ApplyReg=false

	export flags_EPI_postReg=false 

		export flags_EPI_DemeanDetrend=true 	# Typically not needed since regressors have been z-scored and 
												# and an intercept has been added to the regression matrix.
												# DCT removes linear and quadratic trends so detrending is not needed either.  

		export flags_EPI_BandPass=true  # Performs Butterworth filtering on residuals. Post regression filtering can potentially 
										# reintroduce artifacts to the signal - see Lindquist et al. 2019 Hum Brain Mapp 
										## WARNING BandPass cannot be applied if DCTs were included in regression. 

			export configs_EPI_fMin=0.009
			export configs_EPI_fMax=0.08


		export configs_EPI_scrub=false     # remove outlier volumes based on joint FD and DVARS computed before nuissance regression

			if ${configs_EPI_scrub}; then
				nR="scrubbed_${nR}"
			fi

		# =========================================================================================
		# USER INSTRUCTIONS - DON'T MODIFY THE FOLLOWING SECTION
		#===========================================================================================
		if ${configs_EPI_DCThighpass} && ${flags_EPI_BandPass}; then
			log "ERROR 	Please select one option only: DCT high-pass or Butterworth filtering. Exiting... "
			exit 1
		fi

		if ${flags_EPI_DVARS} && ${configs_EPI_scrub}; then
			log "ERROR 	Please select one option only: regression with DVARS or post-regression scrubbing with pre-regression FD and DVARS. Exiting... "
			exit 1
		fi
		#===========================================================================================


	export nR 

	export flags_EPI_ROIs=false

fi

################################################################################
############################# DWI processing ###################################

## USER INSTRUCTIONS - SET THIS FLAG TO "false" IF YOU WANT TO SKIP THIS SECTION
## ALL FLAGS ARE SET TO DEFAULT SETTINGS
export DWI_A=false

if $DWI_A; then

	export scanner="SIEMENS" #  SIEMENS or GE
	log "SCANNER ${scanner}"

	if [[ ${scanner} == "SIEMENS" ]]; then
		export scanner_param_EffectiveEchoSpacing="EffectiveEchoSpacing"  # "EffectiveEchoSpacing" for Siemens; "effective_echo_spacing" for GE
		export scanner_param_slice_fractimes="SliceTiming"  # "SliceTiming" for Siemens; "slice_timing" for GE
		export scanner_param_TotalReadoutTime="TotalReadoutTime"
		export scammer_param_AcquisitionMatrix="AcquisitionMatrixPE"
		export scanner_param_PhaseEncodingDirection="PhaseEncodingDirection"
	elif [[ ${scanner} == "GE" ]]; then
		export scanner_param_EffectiveEchoSpacing="effective_echo_spacing"  # "EffectiveEchoSpacing" for Siemens; "effective_echo_spacing" for GE
		export scanner_param_slice_fractimes="slice_timing"  # "SliceTiming" for Siemens; "slice_timing" for GE
		export scanner_param_TotalReadoutTime="TotalReadoutTime"
		export scammer_param_AcquisitionMatrix="acquisition_matrix"
		export scanner_param_PhaseEncodingDirection="phase_encode_direction"
	fi

	export flags_DWI_dcm2niix=true # dicom to nifti coversion
								# not needed if json file(s) are provided/extracted
		export configs_DWI_readout=[] # if empty get from dicom; else specify value
	export flags_DWI_topup=true # FSL topup destortion field estimation
		export configs_DWI_b0cut=1 # maximum B-value to be considered B0
	export flags_DWI_eddy=true # FSL EDDY distortion correction
		export configs_DWI_EDDYf='0.3' # fsl bet threshold for b0 brain mask used by EDDY
		export configs_DWI_repolON=true # use eddy_repol to interpolate missing/outlier data
		export configs_DWI_MBjson=true # read the slices/MB-groups info from the json file (--json option)
	export flags_DWI_DTIfit=true  # Tensor estimation and generation of scalar maps
		export configs_DWI_DTIfitf='0.4' # brain extraction (FSL bet -f) parameter 

fi 



export DWI_B=false

if $DWI_B; then

	export flags_DWI_regT1_2DWI=true
	export flags_DWI_MRtrix=true
	export flags_DWI_connMatrix=true # generate connectivity matrices

fi 


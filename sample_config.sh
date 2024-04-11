#!/bin/bash

################################################################################
################################################################################
## GLOBALS & dependencies

# source bash funcs
source ${EXEDIR}/src/func/bash_funcs.sh

export pathSM="/N/project/connpipe/fMRI_proc_utils"

################################################################################
#########################  SET DATA VARIABLES  #################################

# USER INSTRUCTIONS- Set these paths to your bids rawdata directory and your derivatives directory.
#	path2data directory must contain subject subdirectories in BIDS-compliant format. 
#   path2derivs directory is where a "connpipe" directory will be created (if it doesn't exist already)
#               connpipe will create a subdirectory path2derivs/connpipe/sub-ID/ses-ID to store all output
export path2data="/N/project/connpipe/Data/rawdata"

export path2derivs="/N/project/connpipe/Data/derivatives"

# USER INSTRUCTIONS- Please set this to the bids style session name you want to run.
# "ses-"" is the BIDS standard tag 
# export configs_session="ses-test"  

# ################# RESIDUAL CODE FROM GMEFM UNWARP. NEEDS TO BE UPDATED ###################
# export configs_grefmFolder="GREFM"  # Reserved for Gradient Field Mapping series
# 	export configs_GREmagdcm="MAG_DICOMS" # Gradient echo FM magnitude series
# 	export configs_GREphasedcm="PHASE_DICOMS" # Gradient echo FM phase map series
############################################################################################

################################ PARCELLATIONS #################################

# required
#
export PARC1="Tian2"
export PARC1dir="Tian_Subcortex_S2_3T_FSLMNI152_1mm"
export PARC1pcort=0;
export PARC1pnodal=1;
export PARC1psubcortonly=1;
export PARC1pcrblmonly=0;
#
#export PARC2="suit-crblm"
#export PARC2dir="Cerebellum-MNIfnirt-maxprob-thr0-1mm"
#export PARC2pcort=0;
#export PARC2pnodal=1;
#export PARC2psubcortonly=0;
#export PARC2pcrblmonly=1;
#
export PARC2="buckner-crblm"
export PARC2dir="Buckner2011_yeo7_MNI1mm_LooseMask"
export PARC2pcort=0;
export PARC2pnodal=1;
export PARC2psubcortonly=0;
export PARC2pcrblmonly=1;
#
#export PARC3="schaefer200y17"
#export PARC3dir="Schaefer2018_200Parcels_17Networks_order_FSLMNI152_1mm"
#export PARC3pcort=1;
#export PARC3pnodal=1;
#export PARC3psubcortonly=0;
#export PARC3pcrblmonly=0;
#
export PARC3="schaefer200y7"
export PARC3dir="Schaefer200_7Net_1mm"
export PARC3pcort=1;
export PARC3pnodal=1;
export PARC3psubcortonly=0;
export PARC3pcrblmonly=0;
#
#export PARC2="DKT"
#export PARC2dir="DKTcort"
#export PARC2pcort=1;
#export PARC2pnodal=1;
#export PARC2psubcortonly=0;
#export PARC2pcrblmonly=0;

## USER INSTRUCTIONS - SET THE NUMBER OF PARCELLATIONS THAT YOU WANT TO USE
## FROM THE OPTIONS LISTED ABOVE. YOU MAY ADD YOUR OWN PARCELLATIONS BY FOLLOWING
## THE NAMING FORMAT. NOTE THAT PARCELLATIONS ARE RUN IN THE ORDER IN WHICH THEY ARE 
## LISTED ABOVE. FOR EXAMPLE IF numParcs is set to 1, PARC1="shaefer200_yeo7"
## WILL BE USED
export numParcs=3  # numParcs cannot be less than 1. Schaefer is the defailt parc

################################################################################
############################# MULTI-SECTION FLAGS ##############################

export scanner="SIEMENS" #  SIEMENS or GE
	
#### THE DENOISING FLAG IS USED IN T1_PREAPARE_A AND T1_PREPARE_B SO IT IS SET AS A GLOBAL FALG
#### REGARDLESS OF WHETHER YOU ARE APPLYING DENOISING OR NOT, YOU MUST SET THIS FLAG 
# OPTIONS ARE: "ANTS", "SUSAN" FOR FSL'S SUSAN, OR "NONE" FOR NO DENOISING
configs_T1_denoised="ANTS"

#### GLOBAL PARCELLATION FLAGS THAT ARE USED BY T1_PREPARE_B, FMRI, AND DWI.
# Add a subcortical parcellation (user provided or FSL) from which connectivity will be estimated. 
export configs_T1_addsubcort=true 
	# For a user-provided subcortical parcellation, 
	#  (included in PARC list above and found in ConnPipeSM folder)
	#  set in the desired parcellation name for index "N" with "psubcortonly=1"
	export configs_T1_subcortUser=true # false = default FSL; true = user-provided

# Add a cerebellar parcellation (user provided only) from which connectivity will be estimated.
# Set cerebellar PARC index "N" with "pcrblmonly=1"
export configs_T1_addcrblm=true

################################################################################
############################# T1_PREPARE_A #####################################

## USER INSTRUCTIONS - SET THIS FLAG TO "false" IF YOU WANT TO SKIP THIS SECTION
## ALL CONFIGURATION PARAMETERS ARE SET TO RECOMMENDED DEFAULT SETTINGS
export T1_PREPARE_A=false

if $T1_PREPARE_A; then
		
	# IF NO DENOSING IS REQUIRED:
	  ## SET flags_T1_applyDenoising=true AND configs_T1_denoised="NONE"
    # IF DENOISING HAS ALREADY BEEN APPLYIED AND THUS THE PROCESS CAN BE SKIPPED:
	  ## SET flags_T1_applyDenoising=false AND configs_T1_denoised="ANTS"/"SUSAN" 
	export flags_T1_applyDenoising=true

	export flags_T1_anat=true # run FSL_anat
		export configs_T1_bias=2 # 0 = no; 1 = weak; 2 = strong
		export configs_T1_crop=1 # 0 = no; 1 = yes (lots already done by dcm2niix)

	export flags_T1_extract_and_mask=true # brain extraction and mask generation (only needed for double BET)
		# PLACE NUMERIC ARGUMENTS IN " " IN THIS BLOCK.
		export configs_antsTemplate="NKI"  # options are: ANTS (MICCAI, NKI, IXI) or bet
		export configs_T1_A_betF="0.3" # this are brain extraction parameters with FSL bet
		export configs_T1_A_betG="-0.1"  # see fsl bet help page for more details
		# This is the overlap threshold to assess whether or not the ANTS and BET masks are similar 'enough'
		# Set to empty "" to skip QC BET run.
		export config_brainmask_overlap_thr="0.9"  
		# USER if runnign ANTS, bet will be ran anyway as a QC check for the brain masks.
		# QC output will be printed out in the QC file for each subject. 
	 
	# Re-extract the brain using brain_mask_filled (usefull if mask was manually edited or replaced)
	export flags_T1_re_extract=true; # brain extraction with mask
fi 

################################################################################
############################# T1_PREPARE_B #####################################

## USER INSTRUCTIONS - SET THIS FLAG TO "false" IF YOU WANT TO SKIP THIS SECTION
## ALL CONFIGURATION PARAMETERS ARE SET TO RECOMMENDED DEFAULT SETTINGS
export T1_PREPARE_B=false

if $T1_PREPARE_B; then

	# global registration reference config
	export configs_T1_useMNIbrain=true

	# registration flags (T1 <-> MNI)
	export flags_T1_reg2MNI=true
		export configs_T1_useExistingMats=true
		export configs_T1_fnirtSubSamp="4,4,2,1"

	# apply existing transformations to parcellations
	export flags_T1_regParc=true

	# segmentation flags
	export flags_T1_seg=true	
		export configs_T1_segfastH="0.25"
		export configs_T1_masklowthr=1
		export configs_T1_flirtdof6cost="mutualinfo"

	# parcellation flags
	export flags_T1_parc=true
		# Set number of times that non-subcortical
		# parc gets dilated and remasked to fill GM
		export configs_T1_numDilReMask=3  
		# Determine whether subcortical parcellation gets dilated. 
		# We do NOT recommend dilating user-provided subcort parc (i.e. when global configs_T1_subcortUser=true)
		export configs_T1_dilate_subcort=false
		# We recommed dilating cerebellum mask to ensure no cortical-cerebellum overlap. 
		# this dilation may not be needed for subjects where CSF is enlarged. 
		export configs_dilate_cerebellum=false
			export configs_numDilCereb=1
		
fi

################################################################################
############################# fMRI_A #####################################

## USER INSTRUCTIONS - SET THIS FLAG TO "false" IF YOU WANT TO SKIP THIS SECTION
## ALL CONFIGURATION PARAMETERS ARE SET TO RECOMMENDED DEFAULT SETTINGS
export fMRI_A=false

if $fMRI_A; then

	# SPECIFY TASK TAG (_task-)
	export configs_EPI_task="rest"

	## IF MULTIPLE SCANS PER SESSION (raw func file names have _run-#_ tag):
	# Select which run(s) you want to process by setting the run range.
	# WARNING: ConnPipe can process nii and nii.gz files but only one (nii or nii.gz) should be present in the func directory. 
	# IF THERE IS A SINGLE EPI SESSION (raw func file name does not include the _run- tag), then leave the runMin and runMax EMPTY
	export configs_EPI_runMin= # minimum run-# to be processed
	export configs_EPI_runMax= # maximum run-# to be processed

	# Obtain pertinent scan information from json file.
	export flags_EPI_ReadJson=false
		# If there is no json file with the functional data: 
		# set flag to false and run the pipeline to receive instructions to manually enter epi acquisition parameters
	#==============================================================================#
	#=================================   UNWARPING  ===============================#
	#==============================================================================#
    # User should select the appropriate BOLD image distortion protocol: 
	# 1) Spin echo field maps -- uses FSL's topup and applytopup
	# 2) Gradient echo field maps -- uses FUGE
	
	#============================ OPTION 1: SPIN ECO UNWARP =======================#
	export flags_EPI_SpinEchoUnwarp=false # Requires raw fmap directory and approporiate files.
		## FSL-topup
		export flags_EPI_RunTopup=true # 1=Run topup (1st pass), 0=Run applyTopup only. (saves time if topup output exists). 

	#====================== OPTION 2: GRADIENT FIELD MAP UNWARP =====================#
	export flags_EPI_GREFMUnwarp=false # Requires GREfieldmap directory and appropriate dicoms
    	
		export configs_use_DICOMS=false   # set to true if Extract TE1 and TE2 from the first image of Gradient Echo Magnitude Series
										 # set to false if gre_fieldmap_mag already generated (i.e. STANFORD GE data)	
										 # if set to 'false', GREFMUnwarp code will look for a single Magnitude file and try to extract Mag1 and Mag2
										 # or, it will look for Mag1 and Mag2
			export configs_extract_twoMags=false
			export configs_Mag_file="gre_fieldmap_mag"
				export configs_Mag1="gre_fieldmap_mag_0000.nii.gz"  #if Mag1 and Mag2 already exist, name them here
				export configs_Mag2="gre_fieldmap_mag_0001.nii.gz"
			export configs_Phase_file="gre_fieldmap_phasemap"
		
		export configs_fsl_prepare_fieldmap=true   # Output from fsl_prepare_fieldmap will be in rad/s
												   # https://lcni.uoregon.edu/kb-articles/kb-0003	
		
		export configs_convert2radss=false   # if fieldmap_phasemap is in Hz, then it must be converted to rads/s 
											
				

		export configs_EPI_GREbetf=0.5; # GRE-specific bet values. Do not change
		export configs_EPI_GREbetg=0;   # GRE-specific bet input. Change if needed 
		export configs_EPI_GREdespike=true # Perform FM despiking
		export configs_EPI_GREsmooth=3; # GRE phase map smoothing (Gaussian sigma, mm)

	#==================================================================================#
	#==================================================================================#

	export flags_EPI_SliceTimingCorr=false		
		export configs_EPI_minTR=1.6   # perform Slice Timing correction only if TR > configs_EPI_minTR
		export configs_EPI_UseTcustom=1   # 1: use header-extracted slice times (suggested)

	export flags_EPI_MotionCorr=false   # head motion estimation with FSL's mcflirt; generates 6 motion param for each BOLD image

	export flags_EPI_RegT1=false
		export configs_EPI_epibetF=0.3000;

	export flags_EPI_RegOthers=false
		export configs_EPI_GMprobthr=0.2 # Threshold the GM probability image; change from 0.25 to 0.2 or 0.15										
		export configs_EPI_minVoxelsClust=8 

	export flags_EPI_IntNorm4D=false # Intensity normalization to global 4D mean of 1000

	#=================================================================================================#
	#=================================================================================================#
	### The following sectin has been designed to allow the user to test various processing configuraitons.
	#   Each flag (e.g. flag_EPI_*) is a boolean variable that should be used to indicate whether a particular
	#	section of the pipeline should be executed or not. 
	#   NOTE that, regardless of whether a section is being executed or not (i.e. the flag is set to false), 
	#   the configuration parameters within all sections are being used by the pipeline to read/write file 
	#   the intermediary output files. 
	#   For example: if flags_EPI_NuisanceReg=false, but user intends to generate time-series for data processed
	#   with AROMA, then user must be sure to set configs_NuisanceReg="AROMA" (assuming AROMA has been ran before).
	#================================== MOTION AND OUTLIER CORRECTION ================================#
	export flags_EPI_NuisanceReg=true
	## Nuisance Regressors. There are three options that user can select from to set the configs_NuisanceReg variable:
	# 1) configs_NuisanceReg="AROMA": ICA-based denoising; WARNING: This will smooth your data.
	# 2) configs_NuisanceReg="HMPreg": Head Motion Parameter Regression.  
	# 3) configs_NuisanceReg="AROMA_HMP": apply ICA-AROMA followed by HMPreg. 

		export configs_NuisanceReg="AROMA_HMP"

			# if using ICA-AROMA or ICA-AROMA followed by HMP 
			if [[ ${configs_NuisanceReg} == "AROMA" ]] || [[ ${configs_NuisanceReg} == "AROMA_HMP" ]]; then 
				## USER: by default, ICA_AROMA will estimate the dimensionality (i.e. num of independent components) for you; however, for higher multiband
				## factors with many time-points and high motion subjects, it may be useful for the user to set the dimensionality. THis can be done by
				## setting the desired number of componenets in the following config flag. Leave undefined for automatic estimation 
				export config_AROMA_dim=

				# If AROMA has already been run, save computation time by skipping this step. 
				export run_AROMA=false
			fi

			# if using Head Motion Parameters or ICA-AROMA followed by HMP
			if [[ ${configs_NuisanceReg} == "HMPreg" ]] || [[ ${configs_NuisanceReg} == "AROMA_HMP" ]]; then   
					
				export configs_EPI_numHMP=24  # define the number of regressors Head Motion regressors. 
										      # options are: 12 (6 orig + 6 deriv) or 24 (+sq of 12)

			fi

	#================================ PHYSIOLOGICAL REGRESSORS =================================#
	export flags_EPI_PhysiolReg=true
	# Two options that the user can select from:
	# 1) configs_PhysiolReg="aCompCorr" - aCompCorr; PCA based CSF and WM signal regression (up to 5 components)
	# 2) configs_PhysiolReg=meanPhysReg - mean WM and CSF signal regression
		export configs_PhysiolReg="aCompCor"  

			if [[ ${configs_PhysiolReg} == "aCompCor" ]]; then  ### if using aCompCorr

				export configs_EPI_numPhys=5   # defind the number of Principal Components to be used in regression. 
											   # Options are: 1 - 5 PC's. We recommend 5 components. 
											   # Set this option to 6 to include running regression with 1, 2, 3, 4 and 5 PC's. 

			elif [[ ${configs_PhysiolReg} == "meanPhysReg" ]]; then  ### if using WM and CSF mean signal regression

				export configs_EPI_numPhys=2  # define how many regressors to use. 
										      # options are: 2-mean signal; 4-mean signal+derivatives; 8-mean signal+derivatives+sq
		
			fi
	
	#================================ GLOBAL SIGNAL REGRESSION =================================#
	export flags_EPI_GS=true # compute global signal regressors 
			
		export configs_EPI_numGS=4 # define number of global signal regressors
										# Options are  
										#			0 - No global signal regression.
										#           1 - regress mean signal; 
										#           2 - regress mean signal+deriv; 
										#           4 - regress mean signal+deriv+sq

	#================================ FREQUENCY FILTERING =================================# 
	export flags_EPI_FreqFilt=true  # compute Frequency filtering

		export configs_FreqFilt="DCT"   # Options are one of the following:
		#										DCT - Discrete Cosine Transfrom for a high-pass filter 
	    # 										BPF - Bandpass Butterworth Filter 

				# DCT: Perform highpass filtering within regression using Discrete Cosine Transforms.
				if [[ ${configs_FreqFilt} == "DCT" ]]; then 
					export configs_EPI_dctfMin=0.009  # Specify level of high-pass filtering in Hz, 
												# i.e. the lowest frequency signals that will be retained 
												# The appropriate number (k) of DCT bases will be determined as follows:
												# k = fMin * 2 * TR * numTimePoints 
				fi

				# Demeans and detrends the data. Performs Butterworth filtering on residuals
				## NOTE that BPF will be applied to residuals AFTER the regression step (ApplyReg).
				# Post regression filtering can potentially reintroduce artifacts to the signal 
				#  		=> see Lindquist et al. 2019 Hum Brain Mapp 
				if [[ ${configs_FreqFilt} == "BPF" ]]; then   
					export configs_EPI_fMin=0.009
					export configs_EPI_fMax=0.08
				fi

    #==================================== APPLY REGRESSION ===================================#
	## Apply regression using all previously specified regressors
	export flags_EPI_ApplyReg=true
		
		export configs_EPI_despike=true # Dual-approach regression (Mejia 2023) 
										# based on statistical DVARS selection (Afyouni & Nichols 2018)
										# WARNING: Despike and Scrub are mutually exculise!!! 
										# IF both are set to true, scrubbing will be skipped.

	#### We've designed the pipeline so that various configurations can be tested without needing to rerun everything.
	#### If user wants to test both approaches, despiking and scrubbing, run the regression first (flags_EPI_ApplyReg=true)  
	#	 with configs_EPI_despike=true and configs_scrub="no_scrub". Then, to generate scrubbed (non-despiked) data
	#	 simply set flags_EPI_FreqFilt=false, flags_EPI_ApplyReg=false (i.e no need to repeat regression and filtering),
	#	 configs_EPI_despike=false (no despiking) and set flags_EPI_scrub=true and select the desired configs_scrub option

	#=============================== POST REGRESSION SCRUBBING =================================# 
	## Run one of the scrubbing methods
	export flags_EPI_scrub=false 
		export configs_scrub="no_scrub"   # User can select scrubbing based on:
											#    stat_DVARS: statisitical DVARS (Afyouni & Nichols 2018)
											#    fsl_fd_dvars: FSL's FD & DVARS 	
											#	 no_scrub: data will not be scrubbed. 	
	# WARNING: Scrubbing and Despiking are mutually exclusive. If configs_EPI_despike=true, then scrubbing will not be applied. 
	#		   The flag flags_EPI_scrub indicates whether or not to run the scrubbing step. The value of the config variable
	#		   configs_scrub is always used by the ROIs step (below) to find the approprate time-series file, even when
	#		   flags_EPI_scrub=false. Therefore, configs_scrub must be set to "no_scrub" if user does not want scrubbed data. 


	#================ COMPUTE ROI TIME-SERIES FOR EACH NODAL PARCELLATION ======================#
	# Make sure the parcellation relevant multi-seciton flags at the top are set as desired. 
	export flags_EPI_ROIs=true

#=================================================================================================#
#=================================================================================================#
		log $nR
		log $post_nR
	#=======################################ EXTRAS ###############################=========#
	
	export flags_EPI_ReHo=false  # COMPUTE ReHo	
		export configs_ReHo_input="5_epi_hmp24_mPhys2_Gs2.nii.gz"
		export configs_ReHo_neigh="-neigh_RAD 3"  # Specify the neighborhood in voxels or in millimiters. Options are:
										# " "  Leave string empty (e.g. "") for default, 27 voxels (face/edge/corner)
										# "-nneigh 7"  face adjacent voxels
										# "-nneigh 19" face and edge adjacent voxels 
										# "-neigh_RAD X" to specify radius in millimeters; X must be an integer
		export configs_ReHo_mask=		# Specify the full path and name of MNI mask that you want to use								
										  # if not specified, the rT1_brain_mask_FC.nii.gz will be used. 
		export configs_ReHo_MNIres="2"    # Specify the resolution of the reference image
										   # Options are "1" for 1mm, "2" for 2mm. Enter custom resolution
										   # to use flirt to resample your data to selected resolution. 
		
		export configs_ReHo_dirName="ReHo_hmp24_mPhys2_Gs2_maskFC_neigh_RAD3"   
		# We recommend naming the directory with the parameters used to do analysis


	export flags_EPI_ALFF=false  # COMPUTE ALFF/fALFFo	
		export configs_ALFF_input="5_epi_hmp24_mPhys2.nii.gz"

		export configs_ALFF_blur="-blur 6"  # Specify size of smoothing kernel. 
												# Leave string empty (e.g. "") for no blurying
		export configs_ALFF_bandpass="-band 0.01 0.1"  # Specify low/high values for bandpass filter
															# Leave string empty (e.g. "") for no bandpass

		export configs_ALFF_mask=		# Specify the full path and name of MNI mask that you want to use								
										  # if not specified, the rT1_brain_mask_FC.nii.gz will be used. 

		export configs_ALFF_MNIres=2.5    # Specify the resolution of the reference image
										   # Options are "1", 1mm, "2", 2mm, or user defined. 
		
		export configs_ALFF_otherOptions="-despike -nodetrend"  # Specify other ALFF options
												# some options are "-despike -nodetrend -un_bp_out"
												# Leave string empty (e.g. "") for no bandpass
		export configs_ALFF_dirName="ALFF_hmp24_mPhys2_maskFC"

fi

################################################################################
############################# DWI processing ###################################

## USER INSTRUCTIONS - SET THIS FLAG TO "false" IF YOU WANT TO SKIP THIS SECTION
## ALL FLAGS ARE SET TO DEFAULT SETTINGS
export DWI_A=false

if $DWI_A; then

	# export scanner="SIEMENS" #  SIEMENS or GE
	# log "SCANNER ${scanner}"

	# if [[ ${scanner} == "SIEMENS" ]]; then
	# 	export scanner_param_EffectiveEchoSpacing="EffectiveEchoSpacing"  # "EffectiveEchoSpacing" for Siemens; "effective_echo_spacing" for GE
	# 	export scanner_param_slice_fractimes="SliceTiming"  # "SliceTiming" for Siemens; "slice_timing" for GE
	# 	export scanner_param_TotalReadoutTime="TotalReadoutTime"
	# 	export scammer_param_AcquisitionMatrix="AcquisitionMatrixPE"
	# 	export scanner_param_PhaseEncodingDirection="PhaseEncodingDirection"
	# elif [[ ${scanner} == "GE" ]]; then
	# 	export scanner_param_EffectiveEchoSpacing="effective_echo_spacing"  # "EffectiveEchoSpacing" for Siemens; "effective_echo_spacing" for GE
	# 	export scanner_param_slice_fractimes="slice_timing"  # "SliceTiming" for Siemens; "slice_timing" for GE
	# 	export scanner_param_TotalReadoutTime="TotalReadoutTime"
	# 	export scammer_param_AcquisitionMatrix="acquisition_matrix"
	# 	export scanner_param_PhaseEncodingDirection="phase_encode_direction"
	# fi
	
	export flags_DWI_topup=true # FSL topup destortion field estimation
		export configs_DWI_b0cut=1 # maximum B-value to be considered B0
	export flags_DWI_eddy=true # FSL EDDY distortion correction
		export flags_EDDY_prep=true # Generatates eddy input files
			export configs_DWI_EDDYf='0.17' # fsl bet threshold for b0 brain mask used by EDDY
		export flags_EDDY_run=true # Runs EDDY openmp
			export configs_DWI_repolON=true # use eddy_repol to interpolate missing/outlier data
			export configs_DWI_MBjson=true # read the slices/MB-groups info from the json file (--json option)
	export flags_DWI_DTIfit=true  # Tensor estimation and generation of scalar maps
		export configs_DWI_DTIfitf='0.17' # brain extraction (FSL bet -f) parameter 
fi 

export DWI_B=true

if $DWI_B; then

	export flags_DWI_regT1=false
	export flags_DWI_MRtrix=true
		# if streamline file has been created, you can skip this step
		export configs_DWI_skip_streamlines=false
        # Number of threads must be <= --ntasks-per-node of your Slurm jobs
        export configs_DWI_nthreads=4 # for mrtrix tckgen
		export configs_DWI_seeding="wm" # 'wm'-white matter OR 'dyn'-dynamic
			# For WM seeding option, specify number of seeds/voxel
		    export configs_DWI_Nseeds="1000"
        # tracking options
        export configs_DWI_step_sizes="1 1.5 2"
        export configs_DWI_max_angles="30 45 60" # fine coverage if you ask me!
		# filtering options
		export configs_DWI_sift_term_number="1000" 
	export flags_DWI_connMatrix=false # generate connectivity matrices  
fi 

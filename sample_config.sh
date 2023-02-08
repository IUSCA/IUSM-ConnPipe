#!/bin/bash


################################################################################
################################################################################
## GLOBALS & dependencies

# source bash funcs
source ${EXEDIR}/src/func/bash_funcs.sh

## Path to Supplementary Materials. Please download from: 
# https://drive.google.com/drive/folders/1b7S9UcWDeDXVx3NUjuO8NJxxmChgNQ1G?usp=sharing 
export pathSM="/N/project/ConnPipelineSM"

################################################################################
############################  PATH TO DATA  ###################################

# USER INSTRUCTIONS- PLEASE SET THIS PATH TO POINT TO YOUR DATA DIRECTORY
export path2data="/N/project/DataDir"

    ## USER: if running all subjects in the path2data directory, set this flag to true; 
    ## set to false if you'd like to process a subset of subjects 
    export runAll=false 

    ## USER -- if running a subset of subjects, a list of subject ID's can be read from 
    ## a text file located in path2data; user can name the file here:
    # export subj2run="subj2run_AAK.txt"
    export subj2run="subj2run.txt"

################################################################################
#####################  SET UP DIRECTORY STRUCTURE  #############################

# USER INSTRUCTIONS - The following diagram is a sample directory tree for a single subject.
# Following that are configs you can use to set your own names if different
# from sample structure.

# SUBJECT1 -- T1 -- DICOMS
#          |
#          -- EPI(#) -- DICOMS (May have multiple EPI scans)
#          |         
#          |               (SPIN-ECHO)       (GRADIENT ECHO)
#          -- UNWARP1 -- SEFM_AP_DICOMS (OR) GREFM_MAG_DICOMS
#          |         
#          |          -- SEFM_PA_DICOMS (OR) GREFM_PHASE_DICOMS
#          |         
#          |               (SPIN-ECHO)       (GRADIENT ECHO)
#          -- UNWARP2 -- SEFM_AP_DICOMS (OR) GREFM_MAG_DICOMS
#          |          
#          |          -- SEFM_PA_DICOMS (OR) GREFM_PHASE_DICOMS
#          |
#          -- DWI -- DICOMS
#                 |
#                 -- UNWARP -- B0_PA_DCM

export configs_T1="T1"
# for multiple EPI sessions, specify only the base name of folder
# i.e. if there are EPI1, EPI2, EPI3, set configs_epiFolder="EPI"
# for a single EPI session, specify the exact name of the folder
# i.e. if the folder is EPI1, set configs_epiFolder="EPI1"
export configs_epiFolder="EPI" 
	export configs_dcmFolder="DICOMS"
	export configs_dcmFiles="dcm" #"dcm" # specify Dicom file extension
	export configs_niiFiles="nii" # Nifti-1 file extension

# for multiple EPI & UNWARP folders, specify only the base name of folder
# i.e. if there are UNWARP1, UNWARP2, UNWARP3, set configs_sefmFolder="UNWARP"
# for a single UNWARP folder, specify the exact name of the folder
# i.e. if the folder is UNWARP1, set configs_sefmFolder="UNWARP1"
# if using a single UNWARPi folder with multiple EPIj sessions, then
# spcify the exact name of the UNWARPi folder. 
export configs_sefmFolder="UNWARP" # Reserved for Spin Eco Field Mapping series
	export configs_APdcm="SEFM_AP_DICOMS" # Spin Echo A-P
	export configs_PAdcm="SEFM_PA_DICOMS" # Spin Echo P-A

export configs_grefmFolder="GREFM"  # Reserved for Gradient Field Mapping series
	export configs_GREmagdcm="MAG_DICOMS" # Gradient echo FM magnitude series
	export configs_GREphasedcm="PHASE_DICOMS" # Gradient echo FM phase map series


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
################################ PARCELLATIONS #################################

# required parc
export PARC0="CSFvent"
export PARC0dir="${pathSM}/MNI_templates/MNI152_T1_1mm_VentricleMask.nii.gz"
export PARC0pcort=0;
export PARC0pnodal=0;
export PARC0psubcortonly=0;

# optional
export PARC1="tian_subcortical_S2"
export PARC1dir="Tian_Subcortex_S2_3T_FSLMNI152_1mm"
export PARC1pcort=0;
export PARC1pnodal=1;
export PARC1psubcortonly=1;

# required
# Schaefer parcellation of yeo17 into 200 nodes
export PARC2="schaefer200_yeo17"
export PARC2dir="Schaefer2018_200Parcels_17Networks_order_FSLMNI152_1mm"
export PARC2pcort=1;
export PARC2pnodal=1;
export PARC2psubcortonly=0;

# Schaefer parcellation of yeo17 into 300 nodes
# optional
export PARC3="schaefer300_yeo17"
export PARC3dir="Schaefer2018_300Parcels_17Networks_order_FSLMNI152_1mm"
export PARC3pcort=1;
export PARC3pnodal=1;
export PARC3psubcortonly=0;

# optional
export PARC4="yeo17"
export PARC4dir="yeo17_MNI152"
export PARC4pcort=1;
export PARC4pnodal=0;
export PARC4psubcortonly=0;


## USER INSTRUCTIONS - SET THE NUMBER OF PARCELLATIONS THAT YOU WANT TO USE
## FROM THE OPTIONS LISTED ABOVE. YOU MAY ADD YOUR OWN PARCELLATIONS BY FOLLOWING
## THE NAMING FORMAT. NOTE THAT PARCELLATIONS ARE RUN IN THE ORDER IN WHICH THEY ARE 
## LISTED ABOVE. FOR EXAMPLE IF numParcs is set to 1, ONLY CSF AND PARC1="shen_278"
## WILL BE USED
export numParcs=4  # CSF doesn't count; numParcs cannot be less than 1. Schaefer is the defailt parc


############################# T1 DENOISING #####################################

#### THE DENOISING FLAG IS USED IN T1_PREAPARE_A AND T1_PREPARE_B SO IT IS SET AS A GLOBAL FALG
#### REGARDLESS OF WHETHER YOU ARE APPLYING DENOISING OR NOT, YOU MUST SET THIS FLAG 
# OPTIONS ARE: "ANTS", "SUSAN" FOR FSL'S SUSAN, OR "NONE" FOR NO DENOISING
configs_T1_denoised="ANTS"


################################################################################
############################# T1_PREPARE_A #####################################

## USER INSTRUCTIONS - SET THIS FLAG TO "false" IF YOU WANT TO SKIP THIS SECTION
## ALL CONFIGURATION PARAMETERS ARE SET TO RECOMMENDED DEFAULT SETTINGS
export T1_PREPARE_A=false

if $T1_PREPARE_A; then

	export flags_T1_dcm2niix=true  # dicom to nifti conversion 
		export configs_T1_useCropped=false # use cropped field-of-view output of dcm2niix
		
	#### SET flags_T1_applyDenoising=true AND configs_T1_denoised="NONE" IF NO DENOSING IS REQUIRED
	#### SET flags_T1_applyDenoising=FALSE AND configs_T1_denoised="ANTS"/"SUSAN" 
	#### IF DENOISING HAS ALREADY BEEN APPLYIED AND THUS THE PROCESS CAN BE SKIPPED. 
	export flags_T1_applyDenoising=true

	export flags_T1_anat=true # run FSL_anat
		export configs_T1_bias=0 # 0 = no; 1 = weak; 2 = strong
		export configs_T1_crop=0 # 0 = no; 1 = yes (lots already done by dcm2niix)

	export flags_T1_extract_and_mask=true # brain extraction and mask generation (only needed for double BET)
		export configs_antsTemplate="MICCAI"  # options are: ANTS (MICCAI, NKI, IXI) or bet
		export configs_T1_A_betF="0.3" # this are brain extraction parameters with FSL bet
		export configs_T1_A_betG="-0.1"  # see fsl bet help page for more details
		export config_brainmask_overlap_thr="0.90"  # this is the threshold to assess whether or not the ANTS and BET masks are similar 'ehough"'
		# USER if runnign ANTS, bet will be run anyway as a QC check for the brain maks.
		# QC output will be printed out in the QC file for each subject. 
	 
	export flags_T1_re_extract=true; # brain extraction with mask

fi 

################################################################################
############################# T1_PREPARE_B #####################################

## USER INSTRUCTIONS - SET THIS FLAG TO "false" IF YOU WANT TO SKIP THIS SECTION
## ALL CONFIGURATION PARAMETERS ARE SET TO RECOMMENDED DEFAULT SETTINGS
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
		# Set number of times that non-subcortical
		# parc gets dilated and remasked to fill GM
		export configs_T1_dilate_subcort=false
		# Determine whether subcortical parcellation gets dilated. 
		# We do NOT recommend dilating user-provided subcort parc (i.e. when configs_T1_subcortUser=true)
		export configs_dilate_cerebellum=true
			export configs_numDilCereb=1
		# We recommed dilating cerebellum mask to ensure no cortical-cerebellum overlap. 
		# this dilation may not be needed for subjects where CSF is enlarged. 
		export configs_T1_addsubcort=true 
		# add FSL subcortical to cortial parcellations 	
		# but ONLY to nodal parcellation as individual regions
		# To others add as a single subcortical network.
		export configs_T1_subcortUser=true   
		# false = default FSL; true = user-provided
		# Name of user-provided subcortical parcellation (assumed to be found in ConnPipeSM folder)
		# should be set in the desired parcellation name for index "N" with "psubcortonly=1"	
fi 


################################################################################
############################# fMRI_A #####################################

## USER INSTRUCTIONS - SET THIS FLAG TO "false" IF YOU WANT TO SKIP THIS SECTION
## ALL CONFIGURATION PARAMETERS ARE SET TO RECOMMENDED DEFAULT SETTINGS
export fMRI_A=false 

if $fMRI_A; then

	export scanner="SIEMENS" #  SIEMENS or GE
	log "SCANNER ${scanner}"

	# # set number of EPI sessions/scans
	export configs_EPI_epiMin=1 # minimum scan index to be processed
	export configs_EPI_epiMax=3 # maximum scan index to be processed

	# dicom import
	export flags_EPI_dcm2niix=true
	# obtain pertinent scan information
	export flags_EPI_ReadHeaders=true 
	
		# obtain pertinent scan information through json files generated by dcm2niix
		export flags_EPI_UseJson=true  # if set to false, information will be extracted from DICOM 
									   # file header using dicom_hinfo and header tags. This is not recommeded.

	#==============================================================================#
	#=================================   UNWARPING  ===============================#
	#==============================================================================#
    # User should select the appropriate BOLD image distortion protocol: 
	# 1) Spin echo field maps -- uses FSL's topup and applytopup
	# 2) Gradient echo field maps -- uses FUGE
	 
	# In the case of multiple EPI sessions, please select how to use  
	# calculated distortion fields to be applied to EPI scans 
	export configs_EPI_match=true
	# Options available are:
	# false - Use a single UNWARP folder for a specific range of EPI sessions  
	#    This option will do a single field map calculation and apply topup to all EPI
	#    sessions within the range specified by configs_EPI_epiMin & configs_EPI_epiMax
	# true - Use UNWARPi folder for EPIi session. 
	#	 This option will calculate field maps for each UNWARP folder and apply 
	#    to calculation the corresponding EPI folder, matching index i in EPIi with UNWARPi 
	#    with i in the range specified by configs_EPI_epiMin & configs_EPI_epiMax
	
	#============================ OPTION 1: SPIN ECO UNWARP =======================#
	export flags_EPI_SpinEchoUnwarp=true # Requires UNWARP directory and approporiate dicoms.

    	export configs_EPI_multiSEfieldmaps=true # false - single pair of SE fieldmaps within EPI folder
												 # true -  One or multiple UNWARP folders at the subject level (UNWARP1, UNWARP2,...)
												 #         
	# # SPIN ECHO PAIRS (A-P, P-A) Acquistion on the Prisma
		export configs_EPI_SEnumMaps=3; # Fallback Number of PAIRS of AP and PA field maps.
	# # Defaults to reading *.dcm/ima files in SE AP/PA folders

	# # topup (see www.mccauslanddenter.sc.edu/cml/tools/advanced-dti - Chris Rorden's description
		export flags_EPI_RunTopup=true # true - Run topup (1st pass)
									   # false - Do not rerun if previously completed. 

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

	export flags_EPI_SliceTimingCorr=true		
		export configs_EPI_minTR=1.6   # perform Slice Timing correction only if TR > configs_EPI_minTR
		export configs_EPI_UseTcustom=1   # 1: use header-extracted times (suggested)

	export flags_EPI_MotionCorr=true   # head motion estimation with FSL's mcflirt; generates 6 motion param for each BOLD image

	export flags_EPI_RegT1=true
		export configs_EPI_epibetF=0.3000;

	export flags_EPI_RegOthers=true 
		export configs_EPI_GMprobthr=0.2 # Threshold the GM probability image; change from 0.25 to 0.2 or 0.15										
		export configs_EPI_minVoxelsClust=8 

	export flags_EPI_IntNorm4D=true # Intensity normalization to global 4D mean of 1000

	#============================== MOTION AND OUTLIER CORRECTION ============================#
	export flags_EPI_NuisanceReg=true
	## Nuisance Regressors. There are three options that user can select from to set the flags_NuisanceReg variable:
	# 1) flags_NuisanceReg="AROMA": ICA-based denoising; WARNING: This will smooth your data.
	# 2) flags_NuisanceReg="HMPreg": Head Motion Parameter Regression.  
	# 3) flags_NuisanceReg="AROMA_HMP": apply ICA-AROMA followed by HMPreg. 

		export flags_NuisanceReg="HMPreg"

			# if using ICA-AROMA or ICA-AROMA followed by HMP 
			if [[ ${flags_NuisanceReg} == "AROMA" ]] || [[ ${flags_NuisanceReg} == "AROMA_HMP" ]]; then 
				## USER: by default, ICA_AROMA will estimate the dimensionality (i.e. num of independent components) for you; however, for higher multiband
				## factors with many time-points and high motion subjects, it may be useful for the user to set the dimensionality. THis can be done by
				## setting the desired number of componenets in the following config flag. Leave undefined for automatic estimation 
				export flag_AROMA_dim=

				# If AROMA has already been run, save computation time by skipping that step. 
				export AROMA_exists=false
			fi

			# if using Head Motion Parameters or ICA-AROMA followed by HMP
			if [[ ${flags_NuisanceReg} == "HMPreg" ]] || [[ ${flags_NuisanceReg} == "AROMA_HMP" ]]; then   
					
				export configs_EPI_numReg=24  # define the number of regressors Head Motion regressors. 
										      # options are: 12 (6 orig + 6 deriv) or 24 (+sq of 12)

			fi

	#================================ PHYSIOLOGICAL REGRESSORS =================================#
	export flags_EPI_PhysiolReg=true  
	# Two options that the user can select from:
	# 1) flags_PhysiolReg="aCompCorr" - aCompCorr; PCA based CSF and WM signal regression (up to 5 components)
	# 2) flags_PhysiolReg=meanPhysReg - mean WM and CSF signal regression
		export flags_PhysiolReg="aCompCor"  

			if [[ ${flags_PhysiolReg} == "aCompCor" ]]; then  ### if using aCompCorr

				export configs_EPI_numPhys=5   # defind the number of Principal Components to be used in regression. 
											   # Options are: 1 - 5 PC's. We recommend 5 components. 
											   # Set this option to 6 to include running regression with 1, 2, 3, 4 and 5 PC's. 

			elif [[ ${flags_PhysiolReg} == "meanPhysReg" ]]; then  ### if using WM and CSF mean signal regression

				export configs_EPI_numPhys=2  # define how many regressors to use. 
										      # options are: 2-mean signal; 4-mean signal+derivatives; 8-mean signal+derivatives+sq
		
			fi

	#================================ OPTIONAL REGRESSORS =================================#
	# These regressors will be included in a single regression matrix in conjunction with 
	# previously defined regressors, e.g. HMP and PCA's 
	# Optional regressors to be included are: Global signal, Discrete Cosine Transforms, DVARS

	export flags_EPI_regressOthers=true

		export flags_EPI_GS=true # include global signal regression 
			
			export configs_EPI_numGS=4 # define number of global signal regressors
										# Options are: 1-mean signal; 2-mean signal+deriv; 4-mean signal+deriv+sq
			
		export configs_EPI_DCThighpass=true  # Perform highpass filtering within regression using Discrete Cosine Transforms. 
			
			export configs_EPI_dctfMin=0.009  # Specify level of high-pass filtering in Hz, 
												# i.e. the lowest frequency signals that will be retained 
												# The appropriate number (k) of DCT bases will be determined as follows:
												# k = fMin * 2 * TR * numTimePoints 

		export flags_EPI_DVARS=true 

    #==================================== APPLY REGRESSION ===================================#
	## Apply regression using all previously specified regressors
	export flags_EPI_ApplyReg=true

	#================================ POST-REGRESSION TWEAKS =================================#
	# These processing options will be applied to data after regression. 
	# We do not recommend any post-regression nuissance removal as it can potentially re-introduce 
	# noise to the regressed data. Only post-regression scrubbing is recommended. 

	export flags_EPI_postReg=true 

		export flags_EPI_DemeanDetrend=false 	# Typically not needed since regressors have been z-scored and 
												# and an intercept has been added to the regression matrix.
												# DCT removes linear and quadratic trends so detrending is not needed either.  

		export flags_EPI_BandPass=false  # Performs Butterworth filtering on residuals. Post regression filtering can potentially 
										# reintroduce artifacts to the signal - see Lindquist et al. 2019 Hum Brain Mapp 
										## WARNING BandPass cannot be applied if DCTs were included in regression. 

			export configs_EPI_fMin=0.009
			export configs_EPI_fMax=0.08


		export configs_EPI_scrub=true     # Apply scrubbing:
										  # if flags_EPI_DVARS=true then scrubbing is based on computed DVARS
										  # if flag_EPI_DVARS=false then scrubbing is based on FSL's FD & DVARS 

	#================ COMPUTE ROI TIME-SERIES FOR EACH NODAL PARCELLATION ===================#

	export flags_EPI_ROIs=true

	
	 #=======################################ EXTRAS ###############################=========#

	
	export flags_EPI_ReHo=false  # COMPUTE ReHo	
		export configs_ReHo_input="7_epi_hmp24_mPhys2_Gs2.nii.gz"
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
		export configs_ALFF_input="7_epi_hmp24_mPhys2.nii.gz"

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
	export configs_DWI_DICOMS2_B0only=true # if DICOMS2 are B0's only set to true; if DICOMS2 contains scalars and B0's set to false 
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


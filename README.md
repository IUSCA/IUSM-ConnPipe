# IUSM-ConnPipe

The IU School of Medicine Neuroscience Connectivity Pipeline (IUSM-ConnPipe) executes pre-processing of anatomical, functional, and diffusion magnetic resonance imaging data. This data-processing pipeline has been developed to help coordinate multimodal neuroimaging needs at clinical facilities. IUSM-ConnPipe provides a configuration for the selection, management, and operation of many of the crucial tools which have become standard practice for neuroimaging preprocessing protocols. 

---

# Online-Support

[CLICK HERE](https://docs.google.com/forms/d/e/1FAIpQLSf1QJJCBy90blCoRLAQr5KwlYNzS_llfW0GJ5k7mH3DXZbxwA/viewform) to request and schedule support from a ConnPipe developer. 

---

## Features

For a more detailed overview of the different features and pre-processing options, please visit our [wiki](https://github.com/IUSCA/IUSM-ConnPipe/wiki).

#### Process T1 Data 
* DICOM to Nifti conversion
* Denoise T1 data
* Perform brain extraction
* Generate brain mask
* Perform registration onto MNI space 
* Perform tissue-type segmentation
* Generate tissue-type masks
* Generate subcortical masks
* Intersect parcellations with tissue data

#### Process fMRI Data

* DICOM to Nifti conversion
* Extraction of acquisition parameters from file headers
* Perform unwarping
* Perform slice timing correction
* Perform motion correction
* Perform registration to structural data
* Perform intensity normalization
* Derive motion, physiological and outlier nuisance regressors
* Apply regression to denoise signal
* Perform optional post-regression nuisance removal 
* Compute ROI time-series for nodal parcellations

#### Process DWI Data

* DCICOM to Nifti conversion
* Extract B0 images
* Perform top-up field estimation
* Perform eddy current correction 
* Perform diffusion tensor fitting
* Perform registration of T1 to diffusion space
* Perform tensor modeling and tractography with MRtrix
* Perform deterministic multi-tensor tractography
* Create TrackVis streamline files
* Generate tract-based metric matrices

---

### Built With

* [Bash](https://www.gnu.org/software/bash/) - Coordinating command-line operations
* [Python](https://www.python.org/) - Coordinating data operations

### Prerequisites

This code has been developed to operate with the following software:
  * [FSL version 6.0.1/3](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki)         
  * [AFNI](https://afni.nimh.nih.gov/)                          
  * [dcm2niix (part of MRIcroGL)](https://github.com/rordenlab/dcm2niix)  
  * [ICA-AROMA](https://www.ncbi.nlm.nih.gov/pubmed/25770991)                       
  * [MRtrix3](https://www.mrtrix.org/) 
  * [DVARS](https://github.com/asoroosh/DVARS) 
  * Python 3 (see below for specific Python packages needed)                      

This documentaiton assumes that ConnPipe is being run on an IU HPC system, where all software packages needed to execute the pipeline are installed. There is no need to load the software packages manually as the pipeline will load the needed modules at the time of execution. 

### Installing

Prerequisite software are loaded as environment modules. Provided you have prepared all of the prerequisite software, IUSM-ConnPipe comes ready to run with a Linux system. 

A package with Supplementary Materials will be needed to run the pipeline. This package contains a variety of parcellations, templates and atlases, as well as visualization and QC tools. The package can be downloaded [HERE](https://drive.google.com/drive/folders/1b7S9UcWDeDXVx3NUjuO8NJxxmChgNQ1G) and it is a requirement for the pipeline.  

---
### Executing the Pipeline

The Pipeline is run by executing the **sample_main.sh** file. We recommend making a copy of the **sample_main.sh** file and calling it **main.sh**. 

### Configuring the pipeline

IUSM-ConnPipe comes with a pre-formatted configurations file titled **sample_config.sh** which contains specifications for the desired pipeline processing workflow, including specifying paths to input (raw) and output (derivatives) data, and Supplemental materials. We recommend making a copy of the **sample_config.sh** file and calling it **config.sh**. Note that the name of this configuration file should match the name specified in the **main.sh** file, in line 29 (Line 29 in the **main.sh** script is the only modification that should be done to this script, to specify the configuration to be used when executing the pipeline).

The variable `pathSM` in line 13 should point to the location where the Supplementary Packages have been downloaded and/or saved. 

#### Formatting Raw Subject data.

The following diagram is a sample directory tree for a single subject. The pipeline expects each subject's raw data to be organized according to this structure. All output files will be organized following the same directory structure, saved at the `path2derivs` location (defined below). 

```
# SUBJECT1 -- T1 -- DICOMS
#          |
#          -- EPI1 -- DICOMS (If only one EPI scan then this can be called EPI)
#          |
#          -- EPI2 -- DICOMS (May have multiple EPI scans)
#          |         
#          |               (SPIN-ECHO)       (GRADIENT ECHO)
#          -- UNWARP1  -- SEFM_AP_DICOMS (OR) GREFM_MAG_DICOMS
#          |         
#          |           -- SEFM_PA_DICOMS (OR) GREFM_PHASE_DICOMS
#          |         
#          |               (SPIN-ECHO)       (GRADIENT ECHO)
#          -- UNWARP2  -- SEFM_AP_DICOMS (OR) GREFM_MAG_DICOMS
#          |          
#          |           -- SEFM_PA_DICOMS (OR) GREFM_PHASE_DICOMS
#          |
#          -- DWI -- DICOMS
#                 |
#                 -- UNWARP -- B0_PA_DCM
```

The actual names of the directories can be different from this sample structure, and should be configured accordingly in the **config.sh** script in lines 59 - 93. 


#### Specifying the path for Subject input and output data. 

We highly recommend writting all output data onto a separate location from the raw data. The full path to the input (raw) data and output (derivative) data are specified in the configuration file, **config.sh**, in lines 19 and 25, respectively: 

```
export path2data="../N/project/Raw_Data/subjects"
```
and 
```
export path2derivs="../N/project/Derivatives/ConnPipe"
```

The pipeline expects one directory per subject withint the **path2data** directory. To process all the subjects within the **path2data** directory, set the `runAll` flag (line 29 in the **config.sh** script) to `true`. To run a subset of subjects, create a text file and in it, make a list in column format (no commas needed) of the subject ID (or subject directory names) of the subjects to be processed. for example:
```
Subj1
Subj2
Subj8
Subj22
```
Save the file (you can name it `subj2run.txt`) at the **path2derivs** directory, where the derivatives subject directories will be created and all pipeline ouput files will be written to. The pipeline will create a derivatives directory for each subject (if it doesn't exist already; if the directory exists already then any data in it may be overwritten) at the location specified by **path2derivs**. In **config.sh**, line 32, indicate the name of the text file where you have specified the subset of subjects to be processed. 

#### Enabling or disabling features

To enable or disable a feature of the preprocessing pipeline, identify the corresponding feature controller located in the **config.sh** configurations management file.

For example, disable DWI processing by setting... 

```
export DWI_A=true
```

...to false.

```
export DWI_A=false
```

Analysis specifications will depend on the type of content available in the neuroimaging dataset you are analyzing. ConnPipe provides several options for flexible analysis specifications. For example, one clinical research group may require preprocessing only for T1 data, while another might require preprocessing for T1, fMRI, and DWI altogether. ConnPipe provides options to limit analysis to as few or as many features as is desired by the researcher and allows parametter specifications for many of the processing steps. 

The configuration script is written in bash and therefore, indentation does not impact the script (such as it does in python, for example). However, the **config.sh** script is formatted in a way that uses indentation to indicate a parameter's dependency on a given feature. For example, if the flag `T1_PREPARE_A` in line 157 is set to `false`, then the flags/configurations within lines 161 and 185 will not be read at the time of executing the pipeline. Alternatively, if the user sets `T1_PREPARE_A=true` and the flag `flags_T1_extract_and_mask` (line 177) is set to `false`, then the pipeline will not execute the brain extraction and mask generation scripts, and the configuration variables in lines 178 - 181 will not be utilized. 

#### Preparing packages and modules
While IU's HPC systems provide all the software needed to execute the pipeline, there are some python packages that are not provided with the python modules by default. To check what python packages are available to you, run the following command in a terminal:
```module unload python
module load python/3.9.8
pip list 
```
The last command should list all the python packages that are by default available to you. They should be listed in alphabetical order. The python packages needed to run the pipeline are nibabel, scikit-image, dipy and future. If you don't have them listed there, then do the following:
```
pip install nibabel --user
pip install scikit-image --user
pip install dipy --user
pip install future --user

```
After installing these, type again:
```
pip list
```
And you should be able to see the packages listed now. 

### Running the Pipeline

After the desired configurations have been set, the pipeline can be run by executing the **main.sh** script, using the the following command:

```
./main.sh
```

Assuming all configurations have been set-up as needed, the pipeline should begin processing the specified subject data and saving corresponding outputs to the appropriate directories.

---

## Versions

We have provided a legacy [MATLAB version](https://github.com/IUSCA/IUSM-connectivity-pipeline) available for download via GitHub.


## Authors

* Andrea Avena-Koenigsberger, Indiana University Scalable Compute Archives
* Evgeny Chumin, Indiana University School of Medicine
* John West, Indiana University School of Medicine
* Zikai Lin, Indiana University School of Medicine
* Mario Dzemidzic, Indiana University School of Medicine
* Matt Tharp, Indiana University School of Medicine
* Joaquin Goni, Purdue University
* Enrico Amico, Purdue University

## Acknowledgments

Thank-you to our many collaborators at the [CfN](https://medicine.iu.edu/radiology/research/neuroimaging) and [IUSCA](https://sca.iu.edu/).

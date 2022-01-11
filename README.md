# IUSM-ConnPipe

The IU School of Medicine Neuroscience Connectivity Pipeline (IUSM-ConnPipe) executes pre-processing of anatomical, functional, and diffusion magnetic resonance imaging data. This data-processing pipeline has been developed to help coordinate multimodal neuroimaging needs at clinical facilities. IUSM-ConnPipe provides a configuration for the selection, management, and operation of many of the crucial tools which have become standard practice for neuroimaging preprocessing protocols. 

---

# Online-Support

[CLICK HERE](https://docs.google.com/forms/d/e/1FAIpQLSf1QJJCBy90blCoRLAQr5KwlYNzS_llfW0GJ5k7mH3DXZbxwA/viewform) to request and schedule support from a ConnPipe developer. 

---

## Features

For a more detailed overview of the different features, please visit our [wiki](https://github.com/IUSCA/IUSM-ConnPipe/wiki).

#### Process T1 Data 
* Denoise T1 data
* Perform brain extraction
* Transform into the MNI space 
* Perform tissue-type segmentation
* Generate tissue-type masks
* Generate subcortical masks
* Intersect parcellations with tissue data

#### Process fMRI Data

* Perform spin echo unwarping
* Perform slice timing correction
* Perform motion correction
* Perform registration
* Apply transformations to tissue and parcellation images
* Denoise with ICA-AROMA or HMP regression
* Demean and detrend data
* Identify regions of interest

#### Process DWI Data

* Perform top-up field estimation
* Perform eddy current correction 
* Perform diffusion tensor fitting
* Perform registration
* Generate tissue masks
* Perform Camino tensor modeling and tractography
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

### Installing

Prerequisite software are loaded as environment modules. Provided you have prepared all of the prerequisite software, IUSM-ConnPipe comes ready to run with a Linux system. 

A package with Supplementary Materials will be needed to run the pipeline. This package contains a variety of parcellations, templates and atlases, and visualization tools. The package can be downloaded [HERE](https://drive.google.com/drive/folders/1b7S9UcWDeDXVx3NUjuO8NJxxmChgNQ1G) and it is a requirement for the pipeline.  

---
### Executing the Pipeline

The Pipeline is run by executing the **sample_main.sh** file. We recommend making a copy of the **sample_main.sh** file and calling it **main.sh**. 

#### Specifying subject data

The data direcotry and the name of the configuration file (i.e. **sample_config.sh**, see below) are specified in the **sample_main.sh** file. 
To specify data for preprocessing, change the **path2data** variable in **sample_main.sh**.

```
export path2data="../example/subjects"
```
The pipeline expects one directory per subject withint the **path2data** directory. To process all the subjects within the **path2data** directory, set the `runAll` flag (line 32 of the **sample_main.sh** file) to `true`. To run a subset of subjects, create a new text file and in it, make a list in column format (no commas needed) of the subject ID (or subject directory names) of the subjects to be processed. for example:
```
Subj1
Subj2
Subj8
Subj22
```
Save the file (you can name it `subj2run.txt`) at the **path2data** directory, where the subject directories are located. In line 36 of **sample_main.sh** you will specify the name of the file with the subject ID's that will be processed. 

Beyond line 53, the **sample_main.sh** file should not be modified. 

### Configuring the pipeline

IUSM-ConnPipe comes with a pre-formatted configurations file titled **sample_config.sh** which contains specifications for the desired pipeline processing workflow. We recommend making a copy of the **sample_config.sh** file and calling it **config.sh**. Note that the name of this configuration file should match the name specified in the **main.sh** file, in line 49.

The variable `pathSM` in line 82 should point to the location where the Supplementary Packages have been downloaded and/or saved. 


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

Analysis specifications will depend on the type of content available in the neuroimaging dataset you are analyzing. IUSM ConnPipe provides several options for flexible analysis specifications. For example, one clinical research group may require preprocessing only for T1 data, while another might require preprocessing for T1, fMRI, and DWI altogether. IUSM ConnPipe provides options to limit analysis to as few or as many features as is desired by the researcher. 

#### Preparing packages and modules
To check what python packages are available, run the following command in a terminal:
```module unload python/2.7.16
module load python/3.6.8
pip list 
```
The last command should list all the python packages that are by default available to you. They should be listed in alphabetical order. The two packages needed are nibabel and scikit-image. If you don't have them listed there, then do the following:
```
pip install nibabel --user
pip install scikit-image --user
pip install dipy --user

```
After installing these, type again:
```
pip list
```
And you should be able to see the packages listed now. 

### Running the Pipeline

After the desired configurations have been set, the pipeline can be run by executing the **sample_main.sh** script, using the the following command:

```
./sample_main.sh
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

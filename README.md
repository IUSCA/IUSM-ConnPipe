# IUSM-ConnPipe

The IU School of Medicine Neuroscience Connectivity Pipeline (IUSM-ConnPipe) executes pre-processing of anatomical, functional, and diffusion magnetic resonance imaging data. This data-processing pipeline has been developed to help coordinate multimodal neuroimaging needs at clinical facilities. IUSM-ConnPipe provides a configuration for the selection, management, and operation of many of the crucial tools which have become standard practice for neuroimaging preprocessing protocols. 

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
* Perform tractography

---

### Built With

* [Bash](https://www.gnu.org/software/bash/) - Coordinating command-line operations
* [Python](https://www.python.org/) - Coordinating data operations

### Prerequisites

This code has been developed to operate with the following software:
  * [FSL version 6.0.5.2](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki)
  * [ICA-AROMA](https://www.ncbi.nlm.nih.gov/pubmed/25770991)
  * [MRtrix3](https://www.mrtrix.org/) 
  * [DVARS](https://github.com/asoroosh/DVARS) 
  * Python 3.11.4 (see below for specific Python packages needed)

### Installing



---
### Executing the Pipeline

The Pipeline is run by calling the **hpc_main.sh**.


### Configuring the pipeline

IUSM-ConnPipe comes with a pre-formatted configurations file titled **sample_config.sh** which contains specifications for the desired pipeline processing workflow. We recommend making a copy of the **sample_config.sh** file and calling it **config.sh**. 


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

Analysis specifications will depend on the type of content available in the neuroimaging dataset you are analyzing. IUSM ConnPipe provides several options for flexible analysis specifications.

#### Preparing packages and modules
To check what python packages are available, run the following command in a terminal:
```module load python/3.11.4
pip list 
```
The last command should list all the python packages that are by default available to you. They should be listed in alphabetical order. The two packages needed are nibabel and scikit-image. If you don't have them listed there, then do the following:
```
pip install nibabel --user [ tested with 5.2.0 ]
pip install scikit-image --user [ tested with 0.22.0 ]
pip install dipy --user [ tested with 1.8.0 ]
pip install future --user [ tested with 0.18.3 ]

additionally for ica-aroma
pip install matplotlib --user [ tested with 3.7.2 ]
pip install numpy --user [ tested with 1.23.5 ]
pip install pandas --user [ tested with 2.0.3 ]
pip install seaborn --user [ tested with 0.12.2 ]
```
After installing these, type again:
```
pip list
```
And you should be able to see the packages listed now. 

### Running the Pipeline

After the desired configurations have been set, the pipeline can be run by calling the hpc_main.sh function with 
config and subj2run as input
```
./hpc_main.sh config.sh subj2run.txt
```

Assuming all configurations have been set-up as needed, the pipeline should begin processing the specified subject data and saving corresponding outputs to the appropriate directories.

---

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

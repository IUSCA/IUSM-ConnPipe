#!/bin/bash
#
# Script: f_preproc_DWI.m adaptaion from Matlab script 
#
###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

############################################################################### 

msg2file "=================================="
msg2file "2. Eddy Correction"
msg2file "=================================="
    
## Path to eddy subdirectory
if [[ ! -d "${EDDYpath}" ]]; then
    log " Creating EDDY subdirectory."
    mkdir -p ${EDDYpath}
fi

log "EDDY directory is ${EDDYpath}"

if ${flags_EDDY_prep}; then

    log "Purging existing EDDY subdirectory."
    # remove any existing files
    rm -rf ${EDDYpath}
    log "rm -rf ${EDDYpath}/"
    mkdir -p ${EDDYpath}

    # Prepare inputs for EDDY
        ## Create a B0 mask
    if [[ -d "${TOPUPpath}" ]] && [[ -e "${TOPUPpath}/topup_unwarped.nii.gz" ]]; then
        # inputs if topup was done
        fileIn="${TOPUPpath}/topup_unwarped.nii.gz"
        fileMean="${EDDYpath}/meanb0_unwarped.nii.gz"    
    else
        # if topup distortion not available
        log "WARNING Topup data not found; EDDY will run without topup field."
        # Extract B0 volumes from dataset

        cmd="python ${EXEDIR}/src/func/index_b0_images.py \
        ${DWIpath} ${fileBval} ${configs_DWI_b0cut} "AP""
        log $cmd
        res=$(eval $cmd)

        if [[ ${res} -ne "1" ]]; then
            log "WARNING: No b0 volumes identified. Check quality of ${fileBval}"
        else
            log "B0 indices identified: "
            B0_indices="${DWIpath}/b0indicesAP.txt"
            nB0=0

            while IFS= read -r b0_index
            do 
                echo "$b0_index"
                nB0=$(echo $nB0+1 | bc) ## number of B0 indices 

                fileOut="${EDDYpath}/AP_b0_${b0_index}.nii.gz"

                cmd="fslroi ${fileNifti} ${fileOut} ${b0_index} 1"
                log $cmd
                eval $cmd
            done < "$B0_indices"

        fi 

        # create a list of AP volume names
        ## list all files in EDDY directory
        ### should just be the B0 images
        filesIn=$(find ${EDDYpath} -maxdepth 1 -type f -iname "*.nii.gz")
        echo $filesIn
        B0_list=$(find ${EDDYpath} -maxdepth 1 -type f -iname "*.nii.gz" | wc -l)
        echo "$B0_list AP_b0 volumes were found in ${EDDYpath}"

        ### merge into a 4D volume
        fileOut="${EDDYpath}/all_b0_raw.nii.gz"
        cmd="fslmerge -t ${fileOut} ${filesIn}"
        log $cmd
        eval $cmd 

        ## Inputs if topup was not done
        fileIn="${path_DWI_EDDY}/all_b0_raw.nii.gz"
        fileMean="${path_DWI_EDDY}/meanb0.nii.gz"
    fi 

    # Generate mean B0 image
    cmd="fslmaths ${fileIn} -Tmean ${fileMean}"
    log $cmd
    eval $cmd 

    # run FSL brain extraction to get B0 brain mask
    fileBrain="${EDDYpath}/b0_brain.nii.gz"
    cmd="bet ${fileMean} ${fileBrain} -f ${configs_DWI_EDDYf} -m"
    log $cmd
    eval $cmd

    #####################################################################################
    ## SETTING EDDY INPUTS (EDDYPREP)

    # Set the acqparams, index, and input image data
    ## If no full reverse phase encoding is available
    if [[ "$rtag" -gt 1 ]]; then
 
        # image data
        fileIn="${fileNifti}"
        fileInBvec="${fileBvec}"
        fileInBval="${fileBval}"

        # Find position of b0 volumes in dataset
        cmd="python ${EXEDIR}/src/func/index_b0_images.py \
        ${DWIpath} ${fileInBval} ${configs_DWI_b0cut} "AP""
        log $cmd
        res=$(eval $cmd)

        if [[ ${res} -ne "1" ]]; then
            log "WARNING: No b0 volumes identified. Check quality of ${fileInBval}"
        else
            log "B0 indices identified: "
            B0_indices="${DWIpath}/b0indicesAP.txt"
            nB0=0

            while IFS= read -r b0_index
            do 
                echo "$b0_index"
                nB0=$(echo $nB0+1 | bc) ## number of B0 indices 
            done < "$B0_indices"
        fi  

        # acqparams file
        for ((i = 0; i < $nB0; i++)); do
            echo $APline >> "${EDDYpath}/acqparams_eddy.txt"
        done
        fileInAcqp="${EDDYpath}/acqparams_eddy.txt"

        # Index file
        cmd="python ${EXEDIR}/src/func/get_B0_temporal_info.py ${fileIn} ${B0_indices}"
        log $cmd
        eval $cmd 2>&1 | tee -a ${logfile_name}.log
        fileInIndex="${EDDYpath}/index.txt"

    ## If there are two full reverse phase encoding runs
    elif [[ "$rtag" -eq 1 ]]; then

        #image data: acquistions must be merged into a single 4D file
        fileIn="${DWIpath}/0_DWI_AP-PA.nii.gz"
        cmd="fslmerge -t ${fileIn} ${fileNifti} ${fileNiftiPA}"
        log $cmd
        eval $cmd 
        dim4AP=`fslnvols "${fileNifti}"`

        # now the bvec and bval need to be concatenated

        fileInBvec="${DWIpath}/0_DWI_AP-PA.bvec"
        cat ${fileBvec} > ${fileInBvec}
        cat ${fileBvecPA} >> ${fileInBvec}

        fileInBval="${DWIpath}/0_DWI_AP-PA.bval"
        cat ${fileBval} > ${fileInBval}
        cat ${fileBvalPA} >> ${fileInBval}

        # Find position of b0 volumes in dataset
        cmd="python ${EXEDIR}/src/func/index_b0_images.py \
        ${DWIpath} ${fileInBval} ${configs_DWI_b0cut} "AP-PA""
        log $cmd
        res=$(eval $cmd)

        if [[ ${res} -ne "1" ]]; then
            log "WARNING: No b0 volumes identified. Check quality of ${fileInBval}"
        else
            log "B0 indices identified: "
            B0_indices="${DWIpath}/b0indicesAP-PA.txt"
            nB0=0

            while IFS= read -r b0_index
            do 
                echo "$b0_index"
                nB0=$(echo $nB0+1 | bc) ## number of B0 indices 
            done < "$B0_indices"
        fi  
        
        fileInAcqp="${EDDYpath}/acqparams_AP-PA_eddy.txt"
        # acqparams file
        B0_indices="${DWIpath}/b0indicesAP-PA.txt"
        APnB0=$(wc -l < "${DWIpath}/b0indicesAP.txt")
        for ((i = 1; i <= $nB0; i++)); do
            if [[ $i -le "$APnB0" ]]; then
                echo $APline >> "${fileInAcqp}"
            elif [[ $i -gt "$APnB0" ]]; then
                echo $PAline >> "${fileInAcqp}"
            fi
        done
        

        # Index file
        cmd="python ${EXEDIR}/src/func/get_B0_temporal_info.py ${fileIn} ${B0_indices}"
        log $cmd
        eval $cmd 2>&1 | tee -a ${logfile_name}.log
        fileInIndex="${EDDYpath}/index.txt"
    fi
fi

#####################################################################################
## RUNNING EDDY (EDDYRUN)

if ${flags_EDDY_run}; then

    fileInMask="${EDDYpath}/b0_brain_mask.nii.gz"

    ## If topup output is available
    if [[ -d "${TOPUPpath}" ]] && [[ -e "${TOPUPpath}/topup_results_movpar.txt" ]]; then

        fileInTopup="${TOPUPpath}/topup_results"
        
    fi

    if [[ "$rtag" -gt 1 ]]; then

        # image data
        fileIn="${fileNifti}"
        fileInBvec="${fileBvec}"
        fileInBval="${fileBval}"
        fileInJson="${fileJson}"
        # parameter data
        fileInAcqp="${EDDYpath}/acqparams_eddy.txt"
        fileInIndex="${EDDYpath}/index.txt"

    elif [[ "$rtag" -eq 1 ]]; then

        # image data
        fileIn="${DWIpath}/0_DWI_AP-PA.nii.gz"
        fileInBvec="${DWIpath}/0_DWI_AP-PA.bvec"
        fileInBval="${DWIpath}/0_DWI_AP-PA.bval"
        fileInJson="${fileJson}"
        # parameter data
        fileInAcqp="${EDDYpath}/acqparams_AP-PA_eddy.txt"
        fileInIndex="${EDDYpath}/index.txt"

    fi

    fileOut="${EDDYpath}/eddy_output"

    cmd="eddy_openmp \
    --imain=${fileIn} \
    --mask=${fileInMask} \
    --bvecs=${fileInBvec} \
    --bvals=${fileInBval} \
    --index=${fileInIndex} \
    --acqp=${fileInAcqp}"

    if [[ -d "${TOPUPpath}" ]] && [[ -e "${TOPUPpath}/topup_results_fieldcoef.nii.gz" ]]; then
        cmdT=" \
        --topup=${fileInTopup}"
        cmd+="$cmdT"
    fi
    #Remove and interpolate outlier slices
    ## By default, an outlier is a slice whose average intensity is at
    ## least 4 standard deviations lower than what is expected by the
    ## Gaussian Process Prediction within EDDY.
    if ${configs_DWI_repolON}; then
        log "repolON"
        cmdR=" \
        --repol"
        cmd+="$cmdR"
    else
        log "repolOFF"
    fi
    if ${configs_DWI_MBjson}; then
        cmdJ=" \
        --json=${fileInJson}"
        cmd+="$cmdJ"
    fi

    if [[ -n ${configs_DWI_EDDYargs} ]]; then
        cmdArgs=" \
        ${configs_DWI_EDDYargs}"
        cmd+="$cmdArgs"
    fi

    cmdO=" \
    --out=${fileOut}"
    cmd+="$cmdO"

    log $cmd
    eval $cmd 2>&1 | tee -a ${logfile_name}.log

    # For QC purpoces this created a difference (Delta image) between raw
    # and EDDY corrected diffusion data.

    echo " ---- ${fileOut}"

    if [[ ! -e "${fileOut}.nii.gz" ]]; then
        echo "WARNING  Eddy output not generated. Exiting..."
        exit 1
    else
        log "Computing Delta Eddy image"
        cmd="python ${EXEDIR}/src/func/delta_EDDY.py ${fileOut} ${fileIn}"
        log $cmd
        eval $cmd 2>&1 | tee -a ${logfile_name}.log
        log "Delta Eddy saved"
    fi 
fi
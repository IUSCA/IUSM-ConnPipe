               
#!/bin/bash
#
# Script: fMRI_A adaptaion from Matlab script 
#

###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

############################################################################### 

    msg2file " ==========================================="
    msg2file "      3. BET fMRI and T1 Registration"
    msg2file " ==========================================="
    
    if [[ ! -e "${EPIpath}/2_epi.nii.gz" ]]; then  
        log "WARNING File ${EPIpath}/2_epi.nii.gz does not exist. Skipping further analysis"
        exit 1 
    fi

    #-------------------------------------------------------------------------#
    # compute the mean-vol of epi along 4th dimension (time)

    fileIn="${EPIpath}/2_epi.nii.gz"
    fileOut="${EPIpath}/2_epi_meanvol.nii.gz"
    cmd="fslmaths ${fileIn} -Tmean ${fileOut}"
    log $cmd
    eval $cmd 

    cmd="bet ${fileOut} ${fileOut} -f ${configs_EPI_epibetF} -n -m -R"
    log $cmd
    eval $cmd                
    

    fileIn="${EPIpath}/2_epi.nii.gz"
    fileOut="${EPIpath}/3_epi.nii.gz"
    fileMas="${EPIpath}/2_epi_meanvol_mask.nii.gz"
    cmd="fslmaths ${fileIn} -mas ${fileMas} ${fileOut}"
    log $cmd
    eval $cmd 

    #-------------------------------------------------------------------------#
    # rigid body registration (dof 6) registration of T1 to fMRI

    fileIn="${T1path}/T1_brain.nii.gz"
    fileRef="${EPIpath}/2_epi_meanvol.nii.gz"
    fileOut="${EPIpath}/rT1_brain_dof6"
    fileOmat="${EPIpath}/T1_2_epi_dof6.mat"
    cmd="flirt -in ${fileIn} \
        -ref ${fileRef} \
        -out ${fileOut} \
        -omat ${fileOmat} \
        -cost normmi \
        -dof 6 \
        -interp spline"
    log $cmd
    eval $cmd 

    # generate an inverse transform fMRI to T1
    fileOmatInv="${EPIpath}/epi_2_T1_dof6.mat"
    cmd="convert_xfm -omat ${fileOmatInv} -inverse ${fileOmat}"
    log $cmd 
    eval $cmd 

    #-------------------------------------------------------------------------#
    # Apply transformation to T1 WM mask.

    fileIn="${T1path}/T1_WM_mask.nii.gz"
    fileRef="${EPIpath}/2_epi_meanvol.nii.gz"
    fileOut="${EPIpath}/rT1_WM_mask"
    fileInit="${EPIpath}/T1_2_epi_dof6.mat"
    cmd="flirt -in ${fileIn} \
        -ref ${fileRef} \
        -out ${fileOut} \
        -applyxfm -init ${fileInit} \
        -interp nearestneighbour -nosearch"
    log $cmd
    eval $cmd 

    #-------------------------------------------------------------------------#
    # bbr registration of fMRI to rT1_dof6 based on WMseg

    fileIn="${EPIpath}/2_epi_meanvol.nii.gz"
    #fileOut="${EPIpath}/rT1_brain_dof6bbr.nii.gz"
    fileRef="${EPIpath}/rT1_brain_dof6.nii.gz"
    fileOmat="${EPIpath}/epi_2_T1_bbr.mat"
    fileWMseg="${EPIpath}/rT1_WM_mask"
    cmd="flirt -in ${fileIn} \
        -ref ${fileRef} \
        -omat ${fileOmat} \
        -wmseg ${fileWMseg} \
        -cost bbr"
    log $cmd
    eval $cmd 

    # Generate inverse matrix of bbr (T1_2_epi)
    fileMat="${EPIpath}/epi_2_T1_bbr.mat"
    fileMatInv="${EPIpath}/T1_2_epi_bbr.mat"  
    cmd="convert_xfm -omat ${fileMatInv} -inverse ${fileMat}"
    log $cmd
    eval $cmd 

    # Join the T1_2_epi dof6 and bbr matrices    
    fileMat1="${EPIpath}/T1_2_epi_dof6.mat"
    fileMat2="${EPIpath}/T1_2_epi_bbr.mat"
    fileMatJoint="${EPIpath}/T1_2_epi_dof6_bbr.mat" 
    cmd="convert_xfm -omat ${fileMatJoint} -concat ${fileMat2} ${fileMat1}"               
    log $cmd
    eval $cmd 

    # Join the epi_2_T1 dof and bbr matrices
    fileMat1="${EPIpath}/epi_2_T1_bbr.mat"
    fileMat2="${EPIpath}/epi_2_T1_dof6.mat"
    fileMatJoint="${EPIpath}/epi_2_T1_bbr_dof6.mat" 
    cmd="convert_xfm -omat ${fileMatJoint} -concat ${fileMat2} ${fileMat1}"               
    log $cmd
    eval $cmd    
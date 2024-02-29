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

msg2file "=========================================================="
msg2file "3. Apply transformation to tissue and parcellation images."
msg2file "=========================================================="

if [[ ! -e "${EPIrun_out}/T1_2_epi_dof6_bbr.mat" ]]; then  
    log "WARNING File ${EPIrun_out}/T1_2_epi_dof6_bbr.mat does not exist. Skipping further analysis"
    exit 1 
fi

#-------------------------------------------------------------------------#

# brain 
fileIn="${T1path}/T1_brain.nii.gz"
fileRef="${EPIrun_out}/2_epi_meanvol_mask.nii.gz"
fileOut="${EPIrun_out}/rT1_brain_dof6bbr.nii.gz"
fileInit="${EPIrun_out}/T1_2_epi_dof6_bbr.mat"
cmd="flirt -in ${fileIn} \
    -ref ${fileRef} \
    -out ${fileOut} \
    -applyxfm -init ${fileInit} \
    -interp spline -nosearch"
log $cmd
eval $cmd 

# Compute the volume 
cmd="fslstats ${fileOut} -V"
qc "$cmd"
out=`$cmd`
qc "Number of voxels in ${fileOut} :  $out"

# brain mask
fileIn="${T1path}/T1_brain_mask_filled.nii.gz"
fileRef="${EPIrun_out}/2_epi_meanvol_mask.nii.gz"
fileOut="${EPIrun_out}/rT1_brain_mask"
fileInit="${EPIrun_out}/T1_2_epi_dof6_bbr.mat"
cmd="flirt -in ${fileIn} \
    -ref ${fileRef} \
    -out ${fileOut} \
    -applyxfm -init ${fileInit} \
    -interp nearestneighbour -nosearch"
log $cmd
eval $cmd 

# Compute the volume 
cmd="fslstats ${fileOut} -V"
qc "$cmd"
out=`$cmd`
qc "Number of voxels in ${fileOut} :  $out"

# WM mask
fileIn="${T1path}/T1_WM_mask.nii.gz"
fileOut="${EPIrun_out}/rT1_WM_mask"
cmd="flirt -in ${fileIn} \
    -ref ${fileRef} \
    -out ${fileOut} \
    -applyxfm -init ${fileInit} \
    -interp nearestneighbour -nosearch"
log $cmd
eval $cmd 

# Compute the volume 
cmd="fslstats ${fileOut} -V"
qc "$cmd"
out=`$cmd`
qc "Number of voxels in ${fileOut} :  $out"

# Eroded WM mask
fileIn="${T1path}/T1_WM_mask_eroded.nii.gz"
fileOut="${EPIrun_out}/rT1_WM_mask_eroded"
cmd="flirt -in ${fileIn} \
    -ref ${fileRef} \
    -out ${fileOut} \
    -applyxfm -init ${fileInit} \
    -interp nearestneighbour -nosearch"
log $cmd
eval $cmd 

# Compute the volume 
cmd="fslstats ${fileOut} -V"
qc "$cmd"
out=`$cmd`
qc "Number of voxels in ${fileOut} :  $out"

# CSF mask
fileIn="${T1path}/T1_CSF_mask.nii.gz"
fileOut="${EPIrun_out}/rT1_CSF_mask"
cmd="flirt -in ${fileIn} \
    -ref ${fileRef} \
    -out ${fileOut} \
    -applyxfm -init ${fileInit} \
    -interp nearestneighbour -nosearch"
log $cmd
eval $cmd 

# Compute the volume 
cmd="fslstats ${fileOut} -V"
qc "$cmd"
out=`$cmd`
qc "Number of voxels in ${fileOut} :  $out"

# Eroded CSF mask
fileIn="${T1path}/T1_CSF_mask_eroded.nii.gz"
fileOut="${EPIrun_out}/rT1_CSF_mask_eroded"
cmd="flirt -in ${fileIn} \
    -ref ${fileRef} \
    -out ${fileOut} \
    -applyxfm -init ${fileInit} \
    -interp nearestneighbour -nosearch"
log $cmd
eval $cmd 

# Compute the volume 
cmd="fslstats ${fileOut} -V"
qc "$cmd"
out=`$cmd`
qc "Number of voxels in ${fileOut} :  $out"

# CSF ventricle mask 
fileIn="${T1path}/T1_CSFvent_mask.nii.gz"
fileOut="${EPIrun_out}/rT1_CSFvent_mask"
cmd="flirt -in ${fileIn} \
    -ref ${fileRef} \
    -out ${fileOut} \
    -applyxfm -init ${fileInit} \
    -interp nearestneighbour -nosearch"
log $cmd
eval $cmd  

# Compute the volume 
cmd="fslstats ${fileOut} -V"
qc "$cmd"
out=`$cmd`
qc "Number of voxels in ${fileOut} :  $out"

# CSF ventricle mask eroded
fileIn="${T1path}/T1_CSFvent_mask_eroded.nii.gz"
fileOut="${EPIrun_out}/rT1_CSFvent_mask_eroded"
cmd="flirt -in ${fileIn} \
    -ref ${fileRef} \
    -out ${fileOut} \
    -applyxfm -init ${fileInit} \
    -interp nearestneighbour -nosearch"
log $cmd
eval $cmd  

# Compute the volume 
cmd="fslstats ${fileOut} -V"
qc "$cmd"
out=`$cmd`
qc "Number of voxels in ${fileOut} :  $out"

#-------------------------------------------------------------------------#

# GM reg to fMRI space
fileIn="${T1path}/T1_GM_mask.nii.gz"
fileOut="${EPIrun_out}/rT1_GM_mask_prob"
cmd="flirt -applyxfm \
-init ${fileInit} \
-interp spline \
-in ${fileIn} \
-ref ${fileRef} \
-out ${fileOut} -nosearch"
log $cmd
eval $cmd   

# Compute the volume 
cmd="fslstats ${fileOut} -V"
qc "$cmd"
out=`$cmd`
qc "Number of voxels in ${fileOut}: $out"

# binarize GM probability map
fileIn="${EPIrun_out}/rT1_GM_mask_prob.nii.gz"
fileOut="${EPIrun_out}/rT1_GM_mask"
cmd="fslmaths ${fileIn} -thr ${configs_EPI_GMprobthr} -bin ${fileOut}"
log $cmd
eval $cmd 

# Compute the volume 
cmd="fslstats ${fileOut} -V"
qc "$cmd"
out=`$cmd`
qc "Number of voxels in ${fileOut} :  $out"

#-------------------------------------------------------------------------#
# Apllying T1 to EPI transformations to parcellations

if ${configs_T1_addsubcort} && ! ${configs_T1_subcortUser}; then  # default FSL subcortical

    if [[ -e "${T1path}/T1_GM_parc_FSLsubcort.nii.gz" ]]; then 
  
        log "configs_T1_subcortUser is ${configs_T1_subcortUser} - using FSL default subcortical"
    
        # transformation from T1 to epi space
        fileIn="${T1path}/T1_GM_parc_FSLsubcort.nii.gz"
        fileOut="${EPIrun_out}/rT1_parc_FSLsubcort.nii.gz"

        cmd="flirt -applyxfm -init ${fileInit} \
        -interp nearestneighbour \
        -in  ${fileIn} \
        -ref ${fileRef} \
        -out ${fileOut} -nosearch"
        log $cmd
        eval $cmd 

        # masking with GM
        fileIn="${EPIrun_out}/rT1_parc_FSLsubcort.nii.gz"                        
        fileOut="${EPIrun_out}/rT1_GM_parc_FSLsubcort.nii.gz"
        fileMul="${EPIrun_out}/rT1_GM_mask.nii.gz"

        cmd="fslmaths ${fileIn} \
        -mas ${fileMul} ${fileOut}"
        log $cmd
        eval $cmd                         
            
        # removal of small clusters within ROIs
        fileIn="/rT1_GM_parc_FSLsubcort.nii.gz"                        
        fileOut="/rT1_GM_parc_FSLsubcort_clean.nii.gz"   

        cmd="python ${EXEDIR}/src/func/get_largest_clusters.py \
            ${fileIn} ${fileOut} ${configs_EPI_minVoxelsClust}"                     
        log $cmd
        eval $cmd  
    fi
fi

for ((p=1; p<=numParcs; p++)); do  # exclude PARC0 - CSF - here

    parc="PARC$p"
    parc="${!parc}"
    pcort="PARC${p}pcort"
    pcort="${!pcort}"  
    pnodal="PARC${p}pnodal"  
    pnodal="${!pnodal}" 
    psubcortonly="PARC${p}psubcortonly"    
    psubcortonly="${!psubcortonly}"     
    pcrblmonly="PARC${p}pcrblmonly"    
    pcrblmonly="${!pcrblmonly}"                  

    log "T1->EPI  p is ${p} -- ${parc} parcellation -- pcort is -- ${pcort} -- pnodal is -- ${pnodal}-- psubcortonly is -- ${psubcortonly}-- pcrblmonly is -- ${pcrblmonly}"

    if [ ${psubcortonly} -ne 1 ] && [ ${pcrblmonly} -ne 1 ]; then  # ignore subcortical-only parcellation

        log "psubcortonly -ne 1 -- ${parc} parcellation"
        log "pcrblmonly -ne 1 -- ${parc} parcellation"

        # transformation from T1 to epi space
        fileIn="${T1path}/T1_GM_parc_${parc}.nii.gz" # dropped the dil from testing
        fileOut="${EPIrun_out}/rT1_parc_${parc}.nii.gz"

        cmd="flirt -applyxfm -init ${fileInit} \
        -interp nearestneighbour \
        -in  ${fileIn} \
        -ref ${fileRef} \
        -out ${fileOut} -nosearch"
        log $cmd
        eval $cmd 

        # masking with GM
        fileIn="${EPIrun_out}/rT1_parc_${parc}.nii.gz"                        
        fileOut="${EPIrun_out}/rT1_GM_parc_${parc}.nii.gz"
        fileMul="${EPIrun_out}/rT1_GM_mask.nii.gz"

        cmd="fslmaths ${fileIn} \
        -mas ${fileMul} ${fileOut}"
        log $cmd
        eval $cmd                         
        
        # removal of small clusters within ROIs
        fileIn="/rT1_GM_parc_${parc}.nii.gz"                        
        fileOut="/rT1_GM_parc_${parc}_clean.nii.gz"   

        cmd="python ${EXEDIR}/src/func/get_largest_clusters.py \
            ${fileIn} ${fileOut} ${configs_EPI_minVoxelsClust}"                     
        log $cmd
        eval $cmd           

    elif [ ${psubcortonly} -eq 1 ] && [ ${pcrblmonly} -ne 1 ]; then      
        log "psubcortonly -eq 1 -- ${parc} parcellation"
        log "pcrblmonly -ne 1 -- ${parc} parcellation"

        # transformation from T1 to epi space
        fileIn="${T1path}/T1_GM_parc_${parc}.nii.gz"
        fileOut="${EPIrun_out}/rT1_parc_${parc}.nii.gz"

        cmd="flirt -applyxfm -init ${fileInit} \
        -interp nearestneighbour \
        -in  ${fileIn} \
        -ref ${fileRef} \
        -out ${fileOut} -nosearch"
        log $cmd
        eval $cmd 

        # masking with GM
        fileIn="${EPIrun_out}/rT1_parc_${parc}.nii.gz"                        
        fileOut="${EPIrun_out}/rT1_GM_parc_${parc}.nii.gz"
        fileMul="${EPIrun_out}/rT1_GM_mask.nii.gz"

        cmd="fslmaths ${fileIn} \
        -mas ${fileMul} ${fileOut}"
        log $cmd
        eval $cmd                         
        
        # removal of small clusters within ROIs
        fileIn="/rT1_GM_parc_${parc}.nii.gz"                        
        fileOut="/rT1_GM_parc_${parc}_clean.nii.gz"   

        cmd="python ${EXEDIR}/src/func/get_largest_clusters.py \
            ${fileIn} ${fileOut} ${configs_EPI_minVoxelsClust}"                     
        log $cmd
        eval $cmd  

    elif [ ${psubcortonly} -ne 1 ] && [ ${pcrblmonly} -eq 1 ]; then      
        log "psubcortonly -ne 1 -- ${parc} parcellation"
        log "pcrblmonly -eq 1 -- ${parc} parcellation"

        # transformation from T1 to epi space
        fileIn="${T1path}/T1_parc_${parc}.nii.gz"
        fileOut="${EPIrun_out}/rT1_parc_${parc}.nii.gz"

        cmd="flirt -applyxfm -init ${fileInit} \
        -interp nearestneighbour \
        -in  ${fileIn} \
        -ref ${fileRef} \
        -out ${fileOut} -nosearch"
        log $cmd
        eval $cmd                        
        
        # removal of small clusters within ROIs
        fileIn="/rT1_parc_${parc}.nii.gz"                        
        fileOut="/rT1_parc_${parc}_clean.nii.gz"   

        cmd="python ${EXEDIR}/src/func/get_largest_clusters.py \
            ${fileIn} ${fileOut} ${configs_EPI_minVoxelsClust}"                     
        log $cmd
        eval $cmd         
    fi

done 

# ------------------------------------------------------------------------- ##
# Generate EPI -> MNI and MNI -> EPI transformations

if [[ ! -e "${EPIrun_out}/T1_2_epi_dof6_bbr.mat" ]]; then  
    log "WARNING File ${EPIrun_out}/T1_2_epi_dof6_bbr.mat does not exist. Skipping further analysis"
    exit 1 
fi

T1reg="${T1path}/registration"
    
# EPI -> T1 linear dof6 and bbr (inverse of T1 -> EPI)
fileMat="${EPIrun_out}/T1_2_epi_dof6_bbr.mat"
fileMatInv="${EPIrun_out}/epi_dof6_bbr_2_T1.mat"
cmd="convert_xfm -omat ${fileMatInv} -inverse ${fileMat}"
log $cmd
eval $cmd

# Combine with T12MNI_dof6
fileMat1="${T1reg}/T12MNI_dof6.mat"
fileMat2="${EPIrun_out}/epi_dof6_bbr_2_T1.mat"
fileMatJoint="${EPIrun_out}/epi_2_MNI_dof6.mat"
cmd="convert_xfm -omat ${fileMatJoint} -concat ${fileMat1} ${fileMat2}"
log $cmd
eval $cmd

# Finally, apply T12MNI_dof12 and make an inverse
fileMat1="${T1reg}/T12MNI_dof12.mat"
fileMat2="${EPIrun_out}/epi_2_MNI_dof6.mat"
fileMatJoint="${EPIrun_out}/epi_2_MNI_final.mat"
cmd="convert_xfm -omat ${fileMatJoint} -concat ${fileMat1} ${fileMat2}"
log $cmd
eval $cmd

fileMat="${EPIrun_out}/epi_2_MNI_final.mat"
fileMatInv="${EPIrun_out}/MNI_2_epi_final.mat"
cmd="convert_xfm -omat ${fileMatInv} -inverse ${fileMat}"
log $cmd
eval $cmd
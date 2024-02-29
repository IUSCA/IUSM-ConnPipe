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
msg2file "1. Registration of T1 to b0"
msg2file "=================================="

# check paths
log --no-datetime "path_DWI_EDDY is ${path_DWI_EDDY}"
log --no-datetime "path_DWI_DTIfit is ${path_DWI_DTIfit}"

# up-sample FA image
fileFA2mm="${path_DWI_DTIfit}/3_DWI_FA.nii.gz"
fileFA1mm="${path_DWI_DTIfit}/3_DWI_FA_1mm.nii.gz"

cmd="flirt -in ${fileFA2mm} \
    -ref ${fileFA2mm} \
    -out ${fileFA1mm} \
    -applyisoxfm 1"
log $cmd
eval $cmd

# rigid body of T1 to FA
log "DWI_B: rigid body dof6 T1 -> FA_1mm"
fileIn="${T1path}/T1_brain.nii.gz"
fileMat1="${DWIpath}/T1_2_FA_dof6.mat"
fileOut="${DWIpath}/rT1_dof6.nii.gz"

cmd="flirt -in ${fileIn} \
    -ref ${fileFA1mm} \
    -omat ${fileMat1} \
    -dof 6 \
    -interp spline \
    -out ${fileOut}"
log --no-datetime $cmd
eval $cmd

# remove negatives due to interpolation
cmd="fslmaths ${fileOut} -thr 0 ${fileOut}"
log $cmd
eval $cmd

fileMask="${T1path}/T1_brain_mask.nii.gz"
fileMaskDWI="${DWIpath}/rT1_brain_mask.nii.gz"

cmd="flirt -in ${fileMask} \
    -ref ${fileFA1mm} \
    -applyxfm \
    -init ${fileMat1} \
    -out ${fileMaskDWI} \
    -interp nearestneighbour"
log $cmd
eval $cmd

cmd="fslmaths ${fileOut} -mas ${fileMaskDWI} ${fileOut}"
log $cmd
eval $cmd

# for white matter seeding register WM mask to DWI
if [[ ${configs_DWI_seeding} == "wm" ]]; then
    fileWM="${T1path}/T1_WM_mask.nii.gz"
    fileWMdwi="${DWIpath}/rT1_WM_mask.nii.gz"
    cmd="flirt -in ${fileWM} \
        -ref ${fileFA1mm} \
        -applyxfm \
        -init ${fileMat1} \
        -out ${fileWMdwi} \
        -interp nearestneighbour"
    log $cmd
    eval $cmd
fi

# apply to GM nodal parcellation images
log "DWI_B: apply to GM nodal parcellation images"

for ((p=1; p<=numParcs; p++)); do  # exclude PARC0 - CSF - here

    parc="PARC$p"
    parc="${!parc}"
    pcrblm="PARC${p}pcrblmonly"
    pcrblm="${!pcrblm}"  
    pnodal="PARC${p}pnodal"  
    pnodal="${!pnodal}"                        

    echo "${p}) ${parc} parcellation"

    if [[ "${pnodal}" -eq 1 ]]; then  
        echo " -- Nodal parcellation: ${pnodal}"  
        
        # transformation from T1 to dwi space
        if [[ "${pcrblm}" -eq 1 ]]; then
            fileGMparc="${T1path}/T1_parc_${parc}.nii.gz"
            fileOut="${DWIpath}/rT1_parc_${parc}.nii.gz"
        else
            fileGMparc="${T1path}/T1_GM_parc_${parc}.nii.gz"
            fileOut="${DWIpath}/rT1_GM_parc_${parc}.nii.gz"
        fi

        cmd="flirt -in ${fileGMparc} \
            -ref ${fileFA1mm} \
            -applyxfm \
            -init ${fileMat1} \
            -out ${fileOut} \
            -interp nearestneighbour"
        log $cmd
        eval $cmd
    else
        echo " -- Not a nodal OR cortical parcellation"
    fi
done

# add FSLsubcort

if ! ${configs_T1_subcortUser}; then
    echo "Registering FSLsubcort to DWI"
    fileGMparc="${T1path}/T1_GM_parc_FSLsubcort.nii.gz"
    if [[ -e ${fileGMparc} ]]; then
        # transformation from T1 to dwi space
        fileOut="${DWIpath}/rT1_GM_parc_FSLsubcort.nii.gz"

        cmd="flirt -in ${fileGMparc} \
            -ref ${fileFA1mm} \
            -applyxfm \
            -init ${fileMat1} \
            -out ${fileOut} \
            -interp nearestneighbour"
        log $cmd
        eval $cmd
    else
        echo " GM_parc_FSLsubcort -- Does Not Exist"
    fi
fi
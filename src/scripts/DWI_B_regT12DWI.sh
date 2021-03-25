
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



############################################################################### 


echo "=================================="
echo "1. Registration of T1 to b0"
echo "=================================="

# check paths
log "path_DWI_EDDY is ${path_DWI_EDDY}"
log "path_DWI_DTIfit is ${path_DWI_DTIfit}"

# down-sample FA image
fileFA2mm="${path_DWI_DTIfit}/3_DWI_FA.nii.gz"
fileFA1mm="${path_DWI_DTIfit}/3_DWI_FA_1mm.nii.gz"

cmd="flirt -in ${fileFA2mm} \
    -ref ${fileFA2mm} \
    -out ${fileFA1mm} \
    -applyisoxfm 1"
log $cmd
eval $cmd

# rigid body of T1 to b0
log "DWI_B: rigid body dof 6 to T1"
fileIn="${T1path}/T1_brain.nii.gz"
fileMat1="${DWIpath}/T1_2_FA_dof6.mat"
fileOut="${DWIpath}/rT1_dof6.nii.gz"

cmd="flirt -in ${fileIn} \
    -ref ${fileFA1mm} \
    -omat ${fileMat1} \
    -dof 6 \
    -interp spline \
    -out ${fileOut}"
log $cmd
eval $cmd


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

# apply to GM nodal parcellation images
log "DWI_B: apply to GM nodal parcellation images"

for ((p=1; p<=numParcs; p++)); do  # exclude PARC0 - CSF - here

    parc="PARC$p"
    parc="${!parc}"
    pcort="PARC${p}pcort"
    pcort="${!pcort}"  
    pnodal="PARC${p}pnodal"  
    pnodal="${!pnodal}"                        

    echo "${p}) ${parc} parcellation"

    if [ ${pnodal} -eq 1 ]; then  
        echo " -- Nodal parcellation: ${pnodal}" 
        
        # transformation from T1 to epi space
        fileGMparc="${T1path}/T1_GM_parc_${parc}.nii.gz"
        fileOut="${DWIpath}/rT1_GM_parc_${parc}.nii.gz"

        cmd="flirt -in ${fileGMparc} \
            -ref ${fileFA1mm} \
            -applyxfm \
            -init ${fileMat1} \
            -out ${fileOut} \
            -interp nearestneighbour"
        log $cmd
        eval $cmd
    else
        echo " -- Not a nodal parcellation"
    fi
done
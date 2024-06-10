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

# Load packages/modules
#===========================================================================
module load ${fsl}
module load ${ants}

############################################################################### 

if ${flags_DWI_regT1}; then

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

    # register T1 brain to FA via suick ants linear+nonlinear registration
    log "DWI_B: Ants SyN registration T1 -> FA_1mm"
    fileIn="${T1path}/T1_brain.nii.gz"
    prefixOut="${DWIpath}/rT1_qSyn_"

    cmd="antsRegistrationSyNQuick.sh -d 3 \
        -n ${configs_DWI_nthreads} \
        -f ${fileFA1mm} \
        -m ${fileIn} \
        -o ${prefixOut}"
    log --no-datetime $cmd
    eval $cmd

    # for white matter seeding register WM mask to DWI
    if [[ ${configs_DWI_seeding} == "wm" ]]; then
        fileWM="${T1path}/T1_WM_mask.nii.gz"
        fileWMdwi="${DWIpath}/rT1_WM_mask.nii.gz"
        cmd="antsApplyTransforms -d 3 \
            -i ${fileWM} \
            -r ${fileFA1mm} \
            -n GenericLabel \
            -t ${prefixOut}1Warp.nii.gz \
            -t ${prefixOut}0GenericAffine.mat \
            -o ${fileWMdwi} -v"
        log $cmd
        eval $cmd
    fi
fi

if ${flags_DWI_regParc}; then

    # apply to GM nodal parcellation images
    log "DWI_B: apply to GM nodal parcellation images"
    fileFA1mm="${path_DWI_DTIfit}/3_DWI_FA_1mm.nii.gz"
    prefixOut="${DWIpath}/rT1_qSyn_"

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
            
            cmd="antsApplyTransforms -d 3 \
                -i ${fileGMparc} \
                -r ${fileFA1mm} \
                -n GenericLabel \
                -t ${prefixOut}1Warp.nii.gz \
                -t ${prefixOut}0GenericAffine.mat \
                -o ${fileOut} -v"
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

            cmd="antsApplyTransforms -d 3 \
                -i ${fileGMparc} \
                -r ${fileFA1mm} \
                -n GenericLabel \
                -t ${prefixOut}1Warp.nii.gz \
                -t ${prefixOut}0GenericAffine.mat \
                -o ${fileOut} -v"
            log $cmd
            eval $cmd
        else
            echo " GM_parc_FSLsubcort -- Does Not Exist"
        fi
    fi
fi
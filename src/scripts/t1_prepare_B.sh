
#!/bin/bash
#
# Script: T1_PREPARE_B adaptaion from Matlab script 
# 9/13/20 - integrated updates from Jenya's opt-subcort branch

###############################################################################
#
# Environment set up
#
###############################################################################


shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

###################################################################################

##### Registration of subject to MNI######

# Set registration dir path and remove any existing reg directories
T1reg="${T1path}/registration"


if ${flags_T1_reg2MNI}; then

## Transform subject T1 into MNI space, then using inverse matrices
## transform yeo7, yeo17, shen parcellations and MNI vertricles mask into subject native space

    log "==== Registration between Native t1 and MNI space ==== "

    if [[ $configs_T1_useExistingMats && -d ${T1reg} ]]; then  # check for existing transformation matrices
        
        dof6="${T1reg}/T12MNI_dof6.mat"
        dof6_inv="${T1reg}/MNI2T1_dof6.mat"
        dof12="${T1reg}/T12MNI_dof12.mat"
        dof12_inv="${T1reg}/MNI2T1_dof12.mat"	
        warp="${T1reg}/T12MNI_warp.nii.gz"
        warp_inv="${T1reg}/MNI2T1_warp.nii.gz"	

        check_inputs "dof6"	"dof6_inv" "dof12" "dof12_inv" "warp" "warp_inv"	
        checkcode=$?	

        if [[ $checkcode -eq 1 ]]; then
            log "MISSING required transformation matrices: running reg2MNI"
            configs_T1_useExistingMats=false
            log "useExistingMats is ${configs_T1_useExistingMats}"
        fi
    else
        log "WARNING ${T1reg} not found. Running reg2MNI"
        configs_T1_useExistingMats=false
        log "Resetting useExistingMats = ${configs_T1_useExistingMats}"    
    fi
    

    ## If transformation matrices don't exist, create them
    ## Register T1 to MNI and obtain inverse transformations
    if ! ${configs_T1_useExistingMats}; then

        if [[ -d ${T1reg} ]]; then 
            cmd="rm -rf ${T1reg}"
            log $cmd
            eval $cmd
        fi 
        mkdir -p ${T1reg}        

        # Register T1 to MNI and obtain inverse tranformations
        log "flirt dof 6 -- T1 -> MNI152"

        if ${configs_T1_useMNIbrain}; then
            fileIn="${T1path}/T1_brain.nii.gz"
        else
            fileIn="${T1path}/T1_fov_denoised.nii"
        fi

        if [[ -e "${fileIn}" ]] && [[ -e ${path2MNIref} ]]; then		
            # Linear rigid body registration T1 to MNI	
            dof6="${T1reg}/T12MNI_dof6.mat"

            cmd="flirt -ref ${path2MNIref} \
                -in ${fileIn} \
                -omat ${dof6} \
                -out ${T1reg}/T1_dof6 \
                -cost ${configs_T1_flirtdof6cost} \
                -dof 6 -interp spline"
            log $cmd
            eval $cmd 
            exitcode=$?
            echo $exitcode

            if [[ ${exitcode} -eq 0 ]] && [[ -e ${dof6} ]]; then	
                # inverse matrix flirt dof 6
                dof6_inv="${T1reg}/MNI2T1_dof6.mat"

                cmd="convert_xfm \
                    -omat ${dof6_inv} \
                    -inverse ${dof6}"
                log $cmd
                eval $cmd 
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] || [[ ! -e ${dof6_inv} ]]; then
                    log "WARNING ${dof6_inv} not created. Exiting"
                    exit 1
                fi 
            else 
                log "WARNING ${dof6} not created. Exiting"
                exit 1	
            fi 
        else
            log "MISSING one of these files was not found: ${fileIn} ${path2MNIref} "
        fi 

        log "flirt dof 12 -- T1 -> MNI152"

        if [[ -e "${T1reg}/T1_dof6.nii.gz" ]] && [[ -e ${path2MNIref} ]]; then	
            # Linear affnie registration of T1 to MNI	
            dof12="${T1reg}/T12MNI_dof12.mat"

            cmd="flirt -ref ${path2MNIref} \
                -in ${T1reg}/T1_dof6.nii.gz \
                -omat ${dof12} \
                -out ${T1reg}/T1_dof12 \
                -dof 12 -interp spline"
            log $cmd
            eval $cmd 
            exitcode=$?
            echo $exitcode

            if [[ ${exitcode} -eq 0 ]] && [[ -e ${dof12} ]] && [[ -e "${T1reg}/T1_dof12.nii.gz" ]]; then	
                #inverse matrix flirt dof 12
                dof12_inv="${T1reg}/MNI2T1_dof12.mat"

                cmd="convert_xfm \
                    -omat ${dof12_inv} \
                    -inverse ${dof12}"
                log $cmd
                eval $cmd 
                exitcode=$?
                if [[ ${exitcode} -ne 0 ]] || [[ ! -e ${dof12_inv} ]]; then
                    log "WARNING ${dof12_inv} not created. Exiting"
                    return 1
                fi 
            else 
                log "WARNING ${dof12} or ${T1reg}/T1_dof12.nii.gz not created. Exiting"
                return 1	
            fi 
        else
            log "MISSING files - ${T1reg}/T1_dof6.nii.gz ${path2MNIref} "
        fi 

        log "fnirt"
        if [[ -e "${T1reg}/T1_dof12.nii.gz" ]] && [[ -e ${path2MNIref} ]]; then

            # Nonlinear warp of T1 to MNI
            warp="${T1reg}/T12MNI_warp"

            cmd="fnirt --ref=${path2MNIref} \
                --in=${T1reg}/T1_dof12.nii.gz \
                --cout=${warp} \
                --iout=${T1reg}/T1_warped \
                --subsamp=${configs_T1_fnirtSubSamp}"
            log $cmd
            eval $cmd 
            exitcode=$?
            echo $exitcode
            if [[ ${exitcode} -eq 0 ]] && [[ -e "${warp}.nii.gz" ]] && [[ -e "${T1reg}/T1_warped.nii.gz" ]]; then

                # inverse warp fnirt	
                warp_inv="${T1reg}/MNI2T1_warp.nii.gz"

                cmd="invwarp \
                    --ref=${T1reg}/T1_dof12 \
                    --warp=${warp} \
                    --out=${warp_inv}"
                log $cmd
                eval $cmd 
                exitcode=$?
                if [[ ${exitcode} -ne 0 ]] || [[ ! -e ${warp_inv} ]]; then
                    log "WARNING ${warp_inv} not created. Exiting"
                    return 1
                fi 
            else 
                log "WARNING ${warp}.nii.gz or ${T1reg}/T1_warped.nii.gz not created. Exiting"
                return 1	
            fi 
        else
            log "MISSING files - ${T1reg}/T1_dof12.nii.gz   ${path2MNIref} "
        fi 				
    fi

    # Transform parcellations from MNI to native subject space
    # for every parcellation +1 (Ventricle mask)
    log "TRANSFORM PARCELLATIONS"

    for ((i=0; i<=numParcs; i++)); do

        parc="PARC$i"
        parc="${!parc}"
        echo ${parc}
        parcdir="PARC${i}dir"
        
        if [[ $i -eq 0 ]]; then  # CSF is PARC0
            parcdir="${!parcdir}"
            echo ${parcdir}
            T1parc="${T1path}/T1_mask_${parc}.nii.gz"
            echo ${T1park}
        else            
            parcdir="${pathParcellations}/${!parcdir}/${!parcdir}.nii.gz"  
            echo ${parcdir}      
            T1parc="${T1path}/T1_parc_${parc}.nii.gz"
            echo ${T1park}
        fi

        if [[ -f ${parcdir} ]]; then

            log "PARCELLATION $parc --> T1"

            fileRef="${T1reg}/T1_dof12.nii.gz"
            fileOut="${T1reg}/${parc}_unwarped.nii.gz"

            cmd="applywarp --ref=${fileRef} \
                --in=${parcdir} \
                --warp=${warp_inv} \
                --out=${fileOut} --interp=nn"

            log $cmd    
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] || [[ ! -e ${fileOut} ]]; then
                log "WARNING ${fileOut} not created. Exiting"
                exit 1
            fi 

            # inv dof 12
            fileIn="${T1reg}/${parc}_unwarped.nii.gz"
            fileRef="${T1reg}/T1_dof6.nii.gz"
            fileOut="${T1reg}/${parc}_unwarped_dof12.nii.gz"

            cmd="flirt -in ${fileIn} \
                -ref ${fileRef} \
                -out ${fileOut} \
                -applyxfm \
                -init ${dof12_inv} \
                -interp nearestneighbour \
                -nosearch"

            log $cmd    
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] || [[ ! -e ${fileOut} ]]; then
                log "WARNING ${fileOut} not created. Exiting"
                exit 1
            fi 

            # inv dof 6
            fileIn="${T1reg}/${parc}_unwarped_dof12.nii.gz"

            if ${configs_T1_useMNIbrain}; then
                fileRef="${T1path}/T1_brain.nii.gz"
            else
                fileRef="${T1path}/T1_fov_denoised.nii"
            fi

            fileOut="${T1reg}/${parc}_unwarped_dof12_dof6.nii.gz"

            cmd="flirt -in ${fileIn} \
                -ref ${fileRef} \
                -out ${fileOut} \
                -applyxfm \
                -init ${dof6_inv} \
                -interp nearestneighbour \
                -nosearch"

            log $cmd    
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] || [[ ! -e ${fileOut} ]]; then
                log "WARNING ${fileOut} not created. Exiting"
                exit 1
            fi 

            cmd="cp ${fileOut} ${T1parc}"
            log $cmd
            eval $cmd 
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]]; then
                echoerr "$T1parc not created. Exiting.." 
                exit 1
            fi

        else
            log "MISSING $parc parcellation not found -- $parcdir"
            exit 1
        fi            
    done
fi	

##### Tissue-type segmentation; cleaning; and gray matter masking of parcellations ######

if ${flags_T1_seg}; then
    log "==== Tissue-type Segmentation ==== "

    # Check that T1_brain image exists
    fileIn="${T1path}/T1_brain.nii.gz"
    checkisfile ${fileIn}

    # FSL fast tissue-type segmentation (GM, WM, CSF)
    cmd="fast -H ${configs_T1_segfastH} ${fileIn}"
    log $cmd 
    eval $cmd

    ## CSF masks
    fileIn="${T1path}/T1_brain_seg.nii.gz"
    fileOut="${T1path}/T1_CSF_mask"
    checkisfile ${fileIn}

    cmd="fslmaths ${fileIn} -thr ${configs_T1_masklowthr} -uthr 1 ${fileOut}"
    log $cmd 
    eval $cmd

    cmd="fslmaths ${T1path}/T1_CSF_mask.nii.gz -mul -1 -add 1 ${T1path}/T1_CSF_mask_inv.nii.gz"
    log $cmd 
    eval $cmd

    ## Subcortical masks
    fileIn="${T1path}/${configs_fslanat}.anat/T1_subcort_seg.nii.gz"
    fileOut="${T1path}/T1_subcort_seg.nii.gz"
    checkisfile ${fileIn}

    cmd="cp ${fileIn} ${fileOut}"
    log $cmd
    eval $cmd 

    # binarize subcorticla segmentaiton to a mask
    cmd="fslmaths ${T1path}/T1_subcort_seg.nii.gz -bin ${T1path}/T1_subcort_mask.nii.gz"
    log $cmd 
    eval $cmd

    # remove CSF contamination
    fileIn="${T1path}/T1_subcort_mask.nii.gz"
    fileMas="${T1path}/T1_CSF_mask_inv.nii.gz"  
    fileOut=${fileIn}  

    cmd="fslmaths ${fileIn} -mas ${fileMas} ${fileOut}"
    log $cmd 
    eval $cmd

    cmd="fslmaths ${T1path}/T1_subcort_seg.nii.gz -mas ${fileMas} ${T1path}/T1_subcort_seg.nii.gz"
    log $cmd 
    eval $cmd

    cmd="fslmaths ${fileIn} -mul -1 -add 1 ${T1path}/T1_subcort_mask_inv.nii.gz"
    log $cmd 
    eval $cmd

    ## Adding FIRST subcortical into tissue segmentation
    cmd="fslmaths ${T1path}/T1_brain_seg -mul ${T1path}/T1_subcort_mask_inv ${T1path}/T1_brain_seg_best"
    log $cmd 
    eval $cmd 

    cmd="fslmaths ${T1path}/T1_subcort_mask -mul 2 ${T1path}/T1_subcort_seg_add"
    log $cmd 
    eval $cmd

    cmd="fslmaths ${T1path}/T1_brain_seg_best -add ${T1path}/T1_subcort_seg_add ${T1path}/T1_brain_seg_best"
    log $cmd 
    eval $cmd    

    ## Separating Tissue types
    declare -a listTissue=("CSF" "GM" "WM")
    
    fileIn="${T1path}/T1_brain_seg_best.nii.gz"

    for (( i=0; i<3; i++ )); do
        
        fileOut="${T1path}/T1_${listTissue[$i]}_mask"
        counter=$((i+1))
        
        cmd="fslmaths ${fileIn} -thr $counter -uthr $counter -div $counter ${fileOut}"
        log $cmd
        eval $cmd 

        # erode each tissue mask
        cmd="fslmaths ${fileOut} -ero ${fileOut}_eroded"
        log $cmd
        eval $cmd        

        if [ "$i" -eq 2 ]; then  # if WM

            echo "Performing 2nd and 3rd WM erotion" 

            WMeroded_1st="${T1path}/T1_WM_mask_eroded_1st.nii.gz"
            WMeroded_2nd="${T1path}/T1_WM_mask_eroded_2nd.nii.gz"
            WMeroded_3rd="${T1path}/T1_WM_mask_eroded.nii.gz"

            cmd="mv ${T1path}/T1_WM_mask_eroded.nii.gz ${WMeroded_1st}"
            log $cmd
            eval $cmd 

            # 2nd WM erotion
            cmd="fslmaths ${WMeroded_1st} -ero ${WMeroded_2nd}"
            log $cmd
            eval $cmd

            # 3rd WM erotion
            cmd="fslmaths ${WMeroded_2nd} -ero ${WMeroded_3rd}"
            log $cmd
            eval $cmd        
        fi 

    done

    # apply as CSF ventricles mask
    fileIn="${T1path}/T1_CSF_mask_eroded.nii.gz" 
    fileOut="${T1path}/T1_CSFvent_mask_eroded"
    fileMas="${T1path}/T1_mask_CSFvent.nii.gz"
    checkisfile ${fileMas}

    cmd="fslmaths ${fileIn} -mas ${fileMas} ${fileOut}"
    log $cmd
    eval $cmd

    # apply as CSF ventricles mask without erotion 
    fileIn="${T1path}/T1_CSF_mask.nii.gz" 
    fileOut="${T1path}/T1_CSFvent_mask"
    fileMas="${T1path}/T1_mask_CSFvent.nii.gz"

    cmd="fslmaths ${fileIn} -mas ${fileMas} ${fileOut}"
    log $cmd
    eval $cmd    

    ## WM CSF sandwich 
    echo "WM/CSF sandwich"   

    # Remove any gray matter voxels that are within
    # one dilation of CSF and white matter.

    # Dilate WM mask    
    fileIn="${T1path}/T1_WM_mask.nii.gz"
    fileOut="${T1path}/T1_WM_mask_dil"
    
    cmd="fslmaths ${fileIn} -dilD ${fileOut}"
    log $cmd
    eval $cmd

    # Dilate CSF mask    
    fileIn="${T1path}/T1_CSF_mask.nii.gz"
    fileOut="${T1path}/T1_CSF_mask_dil"
    
    cmd="fslmaths ${fileIn} -dilD ${fileOut}"
    log $cmd
    eval $cmd

    # Add the dilated masks together   
    fileIn1="${T1path}/T1_WM_mask_dil.nii.gz"
    fileIn2="${T1path}/T1_CSF_mask_dil.nii.gz"
    fileOut="${T1path}/T1_WM_CSF_sandwich.nii.gz"
    
    cmd="fslmaths ${fileIn1} -add ${fileIn2} ${fileOut}"
    log $cmd
    eval $cmd

    # Threshold the image at 2, isolationg WM, SCF interface    
    fileIn="${T1path}/T1_WM_CSF_sandwich.nii.gz"
    fileOut="${T1path}/T1_WM_CSF_sandwich.nii.gz"
    
    cmd="fslmaths ${fileIn} -thr 2 ${fileOut}"
    log $cmd
    eval $cmd

    # Multiply the interface by the native space ventricle mask
    fileIn1="${T1path}/T1_WM_CSF_sandwich.nii.gz"
    fileIn2="${T1path}/T1_mask_CSFvent.nii.gz"
    fileOut="${T1path}/T1_WM_CSF_sandwich.nii.gz"
    
    cmd="fslmaths ${fileIn1} -mul ${fileIn2} ${fileOut}"
    log $cmd
    eval $cmd    

    # Using fsl cluster identify the largest contiguous cluster, and save it out as a new mask   
    fileIn="${T1path}/T1_WM_CSF_sandwich.nii.gz"
    textOut="${T1path}/WM_CSF_sandwich_clusters.txt"
    
    cmd="cluster --in=${fileIn} --thresh=1 --osize=${fileIn} >${textOut}"
    log $cmd
    eval $cmd    

    # get the largest cluster from line 2 and column 2
    cluster="$(sed -n 2p ${textOut} | awk '{print $2}' )"

    cmd="fslmaths ${fileIn} -thr ${cluster} ${fileIn}"
    log $cmd
    eval $cmd     

    # Binarize and invert the single cluster mask
    fileIn="${T1path}/T1_WM_CSF_sandwich.nii.gz"
    fileOut="${T1path}/T1_WM_CSF_sandwich"
    
    cmd="fslmaths ${fileIn} -binv ${fileOut}"
    log $cmd
    eval $cmd   

    # Filter the GM mask with obtained CSF_WM sandwich.
    fileIn1="${T1path}/T1_WM_CSF_sandwich.nii.gz"
    fileIn2="${T1path}/T1_GM_mask.nii.gz"
    fileOut="${fileIn2}"
    
    cmd="fslmaths ${fileIn1} -mul ${fileIn2} ${fileOut}"
    log $cmd
    eval $cmd      

fi


##### Intersect parcellations with GM ######

if ${flags_T1_parc}; then

    log "==== PARC->GM Gray matter masking of native space parcellations ==== "

    one_time=true

    for ((i=1; i<=numParcs; i++)); do  # exclude PARC0 - CSF - here

        parc="PARC$i"
        parc="${!parc}"
        pcort="PARC${i}pcort"
        pcort="${!pcort}"  
        pnodal="PARC${i}pnodal"  
        pnodal="${!pnodal}" 
        psubcortonly="PARC${i}psubcortonly"    
        psubcortonly="${!psubcortonly}"

        echo "${parc} parcellation intersection with GM; pcort is -- ${pcort}"

        fileIn="${T1path}/T1_parc_${parc}.nii.gz"
        checkisfile ${fileIn}

        fileOut="${T1path}/T1_parc_${parc}_dil.nii.gz"
        
        # Dilate the parcellation.
        cmd="fslmaths ${fileIn} -dilD ${fileOut}"
        log $cmd
        eval $cmd 

        # Iteratively mask the dilated parcellation with GM.
        fileMul="${T1path}/T1_GM_mask.nii.gz"
        checkisfile ${fileMul}

        # # Apply subject GM mask
        fileOut2="${T1path}/T1_GM_parc_${parc}.nii.gz"

        cmd="fslmaths ${fileOut} -mul ${fileMul} ${fileOut2}"
        log $cmd
        eval $cmd 

        # Dilate and remask to fill GM mask a set number of times
        fileOut3="${T1path}/T1_GM_parc_${parc}_dil.nii.gz"

        for ((j=1; j<=${configs_T1_numDilReMask}; j++)); do

            cmd="fslmaths ${fileOut2} -dilD ${fileOut3}"
            log $cmd
            eval $cmd

            cmd="fslmaths ${fileOut3} -mul ${fileMul} ${fileOut2}"
            log $cmd
            eval $cmd 

        done 

        # Remove the left over dil parcellation images.
        cmd="rm ${fileOut} ${fileOut3}"
        log $cmd
        eval $cmd 

        if [ "${pcort}" -eq 1 ]; then

            log "CORTICAL-PARCELLATION removing subcortical and cerebellar gray matter"
            # -------------------------------------------------------------------------#
            # Clean up the cortical parcellation by removing subcortical and
            # cerebellar gray matter.
            
            if ${one_time}; then

                # Generate inverse subcortical mask to isolate cortical portion of parcellation.
                fileIn="${T1path}/T1_subcort_mask.nii.gz"
                fileMas="${T1path}/T1_GM_mask.nii.gz"            

                if ${configs_T1_subcortUser}; then

                    fileOut=${fileIn}
                    fileMas2="${T1path}/T1_subcort_mask_inv.nii.gz"

                else  # dilate subcort mask 
                    fileOut="${T1path}/T1_subcort_mask_dil.nii.gz"
                    cmd="fslmaths ${fileIn} -dilD ${fileOut}"
                    log $cmd
                    eval $cmd  

                    fileMas2="${T1path}/T1_subcort_mask_dil_inv.nii.gz"                  
                fi

                cmd="fslmaths ${fileOut} -mas ${fileMas} ${fileOut}"
                log $cmd
                eval $cmd 


                cmd="fslmaths ${fileOut} -binv ${fileMas2}"
                log $cmd
                eval $cmd 
                

            fi 

            # --------------------------------------------------------- #
            # Apply subcortical inverse to cortical parcellations.
            fileOut="${T1path}/T1_GM_parc_${parc}.nii.gz"

            cmd="fslmaths ${fileOut} -mas ${fileMas2} ${fileOut}"
            log $cmd
            eval $cmd 

            if ${one_time}; then
                # --------------------------------------------------------- #
                # Generate a cerebellum mask using FSL's FIRST.
                # inverse transform the MNI cerebellum mask

                FileIn="${pathMNItmplates}/MNI152_T1_cerebellum.nii.gz"
                FileWarpInv="${T1reg}/MNI2T1_warp.nii.gz"
                FileRef="${T1reg}/T1_dof12.nii.gz"
                FileOut="${T1reg}/cerebellum_unwarped.nii.gz"

                cmd="applywarp \
                --ref=${FileRef} \
                --in=${FileIn} \
                --warp=${FileWarpInv} \
                --out=${FileOut} \
                --interp=nn"
                log $cmd
                eval $cmd            

                FileIn="${T1reg}/cerebellum_unwarped.nii.gz"
                FileRef="${T1reg}/T1_dof6.nii.gz"
                FileOut="${T1reg}/cerebellum_unwarped_dof12.nii.gz"
                dof12_inv="${T1reg}/MNI2T1_dof12.mat"


                cmd="flirt \
                -in ${FileIn} \
                -ref ${FileRef} \
                -out ${FileOut} \
                -applyxfm \
                -init ${dof12_inv} \
                -interp nearestneighbour
                -nosearch"
                log $cmd
                eval $cmd

                dof6_inv="${T1reg}/MNI2T1_dof6.mat"

                # Dilate Cereb-unwarped
                if ${configs_dilate_cerebellum}; then
                     
                    log "WARING dilating ${FileOut}"
                    
                    fileDil="${T1reg}/cerebellum_unwarped_dof12_dil"

                    cmd="fslmaths ${FileOut} -dilD ${fileDil}"
                    log $cmd
                    eval $cmd 

                    FileIn=${fileDil}
                    FileCereb_bin="${T1reg}/Cerebellum_dil_bin.nii.gz"
                    FileCereb_inv="${T1path}/Cerebellum_dil_Inv.nii.gz"

                else
                    FileIn="${T1reg}/cerebellum_unwarped_dof12"
                    FileCereb_bin="${T1reg}/Cerebellum_bin.nii.gz"
                    FileCereb_inv="${T1path}/Cerebellum_Inv.nii.gz"
                fi

                if ${configs_T1_useMNIbrain}; then
                    FileRef="${T1path}/T1_brain.nii.gz"
                else
                    FileRef="${T1path}/T1_fov_denoised.nii"
                fi
                

                cmd="flirt \
                -in ${FileIn} \
                -ref ${FileRef} \
                -out ${FileCereb_bin} \
                -applyxfm \
                -init ${dof6_inv} \
                -interp nearestneighbour
                -nosearch"            
                log $cmd
                eval $cmd

                # Generate cerebellar inverse mask
                cmd="fslmaths ${FileCereb_bin} -binv ${FileCereb_inv}"
                log $cmd
                eval $cmd

                one_time=false

            fi 

            # #-------------------------------------------------------------------------%    
            # # Remove any parcellation contamination of the cerebellum.                             
            FileIn="${T1path}/T1_GM_parc_${parc}.nii.gz"
            if ${configs_dilate_cerebellum}; then
                FileCereb_inv="${T1path}/Cerebellum_dil_Inv.nii.gz"
            else
                FileCereb_inv="${T1path}/Cerebellum_Inv.nii.gz"
            fi
            
            cmd="fslmaths ${FileIn} -mas ${FileCereb_inv} ${FileIn}"
            log $cmd
            eval $cmd  

        fi

        ## Add subcortical fsl parcellation to cortical parcellations
        if ${configs_T1_addsubcort} && [[ "${psubcortonly}" -eq 0 ]]; then 

            log "NONSUBCORTIICAL PARCELLATION - Adding subcorical parcels"

            if ! ${configs_T1_subcortUser} ; then  # default FSL subcortical

                log "configs_T1_subcortUser is ${configs_T1_subcortUser} - using FSL default subcortical"
                fileSubcort="${T1path}/T1_subcort_seg.nii.gz"

            else

                log "configs_T1_subcortUser is ${configs_T1_subcortUser} - finding User provided subcortical parcellation "  

                onesubcort=false

                for ((ii=1; ii<=numParcs; ii++)); do  # exclude PARC0 - CSF - here

                    parcii="PARC${ii}"
                    parcii="${!parcii}"
                    psubcortonlyii="PARC${ii}psubcortonly"    
                    psubcortonlyii="${!psubcortonlyii}"                      

                    log "Finding Subcortical Parcellation"
                    log "ii is ${ii} -- ${parcii} parcellation -- psubcortonlyii is -- ${psubcortonlyii}"


                    if [[ "${psubcortonlyii}" -eq 1 ]]; then  # find subcortical-only parcellation

                        log "SUBCORTICAL parcellation found: ${parcii}"

                        if ! ${onesubcort} ; then
                            # check that parcellation is available in T1 space
                            fileSubcortUser="T1_GM_parc_${parcii}.nii.gz"

                            if [[ -f "${T1path}/${fileSubcortUser}" ]]; then

                                log "SUBCORTICAL parcellation is available in T1 space: ${T1path}/${fileSubcortUser}"

                                fileSubcort="${T1path}/${fileSubcortUser}"
                                onesubcort=true  # allow only one subcortical-only parcellation

                            fi
                        fi
                    fi 
                done

                if ! ${onesubcort} ; then   # for-loop conditions not met so default to FSL subcortical 
                    fileSubcort="${T1path}/T1_subcort_seg.nii.gz"
                fi

            fi

            log "fileSubcort is ${fileSubcort}"
            
            FileIn="${T1path}/T1_GM_parc_${parc}.nii.gz"
            
            log "ADD_SUBCORT_PARC using ${FileIn} and ${fileSubcort}"
            # call python script
            cmd="python ${EXEDIR}/src/func/add_subcort_parc.py \
                ${FileIn} ${pnodal} \
                ${fileSubcort}"
            log $cmd
            eval $cmd

        fi 


        # 07.26.2017 EJC Dilate the final GM parcellations. 
        # NOTE: They will be used by f_functiona_connectivity
        #  to bring parcellations into epi space.

        if [[ ${psubcortonly} -ne 1 ]]; then

            fileOut4="${T1path}/T1_GM_parc_${parc}_dil.nii.gz"
            cmd="fslmaths ${fileOut2} -dilD ${fileOut4}"
            log $cmd
            eval $cmd 
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]]; then
                echoerr "Dilation of ${parc} parcellation error! Exist status is displayed below, for details"
                log "exitcode: ${exitcode}"
            fi  
        fi 
    done
fi
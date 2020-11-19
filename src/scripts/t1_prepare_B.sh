
#!/bin/bash
#
# Script: T1_PREPARE_B adaptaion from Matlab script 
# 9/13/20 - integrated updates from Jenya's opt-subcort branch

###############################################################################
#
# Environment set up
#
###############################################################################

############################################################################### 

function add_subcort_parc() {
path="$1" pnodal="$2" subcortUser="$3" python - <<END

import os.path
import numpy as np
import nibabel as nib


parcpath=os.environ['path']
print("parcpath is: ",parcpath)

pnodal=int(os.environ['pnodal'])
print("pnodal is: ",pnodal)
print(type(pnodal))

subcortUser=int(os.environ['subcortUser'])
print("subcortUser is: ",subcortUser)
print(type(subcortUser))

head_tail = os.path.split(parcpath)

print(head_tail[0])
print(head_tail[1])

fileSubcort = ''.join([head_tail[0],'/T1_subcort_seg.nii.gz'])
print(fileSubcort)

parc = nib.load(parcpath)
parc_vol = parc.get_data()
#print(parc_vol.shape)
MaxID = np.max(parc_vol)
#print(MaxID)

subcort = nib.load(fileSubcort)
subcort_vol = subcort.get_data()
#ind = np.argwhere(subcort_vol == 16)
#print(ind)

if subcortUser == "false":  # FSL-provided subcortical
    subcort_vol[subcort_vol == 16] = 0
    #ind = np.argwhere(subcort_vol == 16)
    #print(ind)

if pnodal == 1:
    print("pnodal is 1")
    ids = np.unique(subcort_vol)
    print(ids)

    for s in range(0,len(ids)):
        #print(ids[s]) 
        if ids[s] > 0:
            subcort_vol[subcort_vol == ids[s]] = MaxID + s
elif pnodal == 0:
    print("pnodal is 0")
    subcort_vol[subcort_vol > 0] = MaxID + 1


parc_vol[subcort_vol > 0] = 0
parc_vol = np.squeeze(parc_vol) + subcort_vol

#fileOut = ''.join([head_tail[0],'/this_is_a_test.nii'])
parc_vol_new = nib.Nifti1Image(parc_vol.astype(np.float32),parc.affine,parc.header)
nib.save(parc_vol_new,parcpath)

END
}


###################################################################################




shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh


##### Registration of subject to MNI######
if ${flags_T1_reg2MNI}; then

    T1reg="${T1path}/registration"

    if [[ $configs_T1_useExistingMats ]] && [[ -d ${T1reg} ]]; then  # check for existing transformation matrices
        
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
        configs_T1_useExistingMats=false
        log "useExistingMats is ${configs_T1_useExistingMats}"    

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

        log "flirt dof 6 -- T1 -> MNI152"
        if [[ -e "${T1path}/T1_fov_denoised.nii" && -e ${path2MNIref} ]]; then		
            # Linear rigid body registration T1 to MNI	
            dof6="${T1reg}/T12MNI_dof6.mat"

            cmd="flirt -ref ${path2MNIref} \
                -in ${T1path}/T1_fov_denoised.nii \
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
            log "MISSING files - ${T1path}/T1_fov_denoised.nii ${path2MNIref} "
        fi 

        log "flirt dof 12 -- T1 -> MNI152"
        if [[ -e "${T1reg}/T1_dof6.nii.gz" && -e ${path2MNIref} ]]; then	
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
        if [[ -e "${T1reg}/T1_dof12.nii.gz" && -e ${path2MNIref} ]]; then
            # Nonlinear warp of T1 to MNI
            warp="${T1reg}/T12MNI_warp.nii.gz"

            cmd="fnirt --ref=${path2MNIref} \
                --in=${T1reg}/T1_dof12.nii.gz \
                --cout=${warp} \
                --iout=${T1reg}/T1_warped \
                --subsamp=${configs_T1_fnirtSubSamp}"
            log $cmd
            eval $cmd 
            exitcode=$?
            echo $exitcode
            if [[ ${exitcode} -eq 0 ]] && [[ -e ${warp} ]] && [[ -e "${T1reg}/T1_warped.nii.gz" ]]; then
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
                log "WARNING ${warp} or ${T1reg}/T1_warped.nii.gz not created. Exiting"
                return 1	
            fi 
        else
            log "MISSING files - ${T1reg}/T1_dof12.nii.gz   ${path2MNIref} "
        fi 				
    fi

    ## Transform parcellations from MNI to native subject space
    # for every parcellation +1 (Ventricle mask)
    log "PARCELLATIONS"
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
    echo "Tissue-type Segmentation"

    # # Check that T1_brain image exists
    # fileIn="${T1path}/T1_brain.nii.gz"
    # checkisfile ${fileIn}

    # # FSL fast tissue-type segmentation (GM, WM, CSF)
    # cmd="fast -H ${configs_T1_segfastH} ${fileIn}"
    # log $cmd 
    # eval $cmd

    # ## CSF masks
    # fileIn="${T1path}/T1_brain_seg.nii.gz"
    # fileOut="${T1path}/T1_CSF_mask"
    # checkisfile ${fileIn}

    # cmd="fslmaths ${fileIn} -thr ${configs_T1_masklowthr} -uthr 1 ${fileOut}"
    # log $cmd 
    # eval $cmd

    # cmd="fslmaths ${T1path}/T1_CSF_mask.nii.gz -mul -1 -add 1 ${T1path}/T1_CSF_mask_inv.nii.gz"
    # log $cmd 
    # eval $cmd

    # ## Subcortical masks
    # fileIn="${T1path}/${configs_T1_denoised}.anat/T1_subcort_seg.nii.gz"
    # fileOut="${T1path}/T1_subcort_seg.nii.gz"
    # checkisfile ${fileIn}

    # cmd="cp ${fileIn} ${fileOut}"
    # log $cmd
    # eval $cmd 

    # cmd="fslmaths ${T1path}/T1_subcort_seg.nii.gz -bin ${T1path}/T1_subcort_mask.nii.gz"
    # log $cmd 
    # eval $cmd

    # fileIn="${T1path}/T1_subcort_mask.nii.gz"
    # fileMas="${T1path}/T1_CSF_mask_inv.nii.gz"  
    # fileOut=${fileIn}  

    # cmd="fslmaths ${fileIn} -mas ${fileMas} ${fileOut}"
    # log $cmd 
    # eval $cmd

    # cmd="fslmaths ${T1path}/T1_subcort_mask.nii.gz -mul -1 -add 1 ${T1path}/T1_subcort_mask_inv.nii.gz"
    # log $cmd 
    # eval $cmd

    # ## Adding FIRST subcortical into tissue segmentation
    # cmd="fslmaths ${T1path}/T1_brain_seg -mul ${T1path}/T1_subcort_mask_inv ${T1path}/T1_brain_seg_best"
    # log $cmd 
    # eval $cmd 

    # cmd="fslmaths ${T1path}/T1_subcort_mask -mul 2 ${T1path}/T1_subcort_seg_add"
    # log $cmd 
    # eval $cmd

    # cmd="fslmaths ${T1path}/T1_brain_seg_best -add ${T1path}/T1_subcort_seg_add ${T1path}/T1_brain_seg_best"
    # log $cmd 
    # eval $cmd    

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

    # Remove any gray matter voxels that are withing one dilation of CSF and white matter.

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

    # Dilate CSF mask    
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

    echo "Gray matter masking of native space parcellations"

    for ((i=1; i<=numParcs; i++)); do  # exclude PARC0 - CSF - here

        parc="PARC$i"
        parc="${!parc}"
        pcort="PARC${i}pcort"
        pcort="${!pcort}"  
        pnodal="PARC${i}pnodal"  
        pnodal="${!pnodal}" 
        psubcortonly="PARC${i}psubcortonly"    
        psubcortonly="${!psubcortonly}"

        log "${parc} parcellation intersection with GM; pcort is -- ${pcort}"

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

        # Apply subject GM mask
        fileOut2="${T1path}/T1_GM_parc_${parc}.nii.gz"

        cmd="fslmaths ${fileOut} -mul ${fileMul} ${fileOut2}"
        log $cmd
        eval $cmd 

        # Dilate and remask to fill GM mask a set number of times
        for ((j=1; j<=${configs_T1_numDilReMask}; j++)); do
            fileOut3="${T1path}/T1_GM_parc_${parc}_dil.nii.gz"

            cmd="fslmaths ${fileOut2} -dilD ${fileOut3}"
            log $cmd
            eval $cmd

            cmd="fslmaths ${fileOut3} -mul ${fileMul} ${fileOut2}"
            log $cmd
            eval $cmd 

        done 

        # 07.25.2017 EJC Remove the left over dil parcellation images.
        cmd="rm ${fileOut} ${fileOut3}"
        log $cmd
        eval $cmd 



        if [ "${pcort}" -eq 1 ]; then

            log "CORTICAL-PARCELLATION removing subcortical and cerebellar gray matter"
            # -------------------------------------------------------------------------#
            # Clean up the cortical parcellation by removing subcortical and
            # cerebellar gray matter.

            # Generate inverse subcortical mask to isolate cortical portion of parcellation.
            fileIn="${T1path}/T1_subcort_mask.nii.gz"
            fileOut="${T1path}/T1_subcort_mask_dil.nii.gz"
            fileMas="${T1path}/T1_GM_mask.nii.gz"

            cmd="fslmaths ${fileIn} -dilD ${fileOut}"
            log $cmd
            eval $cmd 

            cmd="fslmaths ${fileOut} -mas ${fileMas} ${fileOut}"
            log $cmd
            eval $cmd 

            fileMas2="${T1path}/T1_subcort_mask_dil_inv.nii.gz"

            cmd="fslmaths ${fileOut} -binv ${fileMas2}"
            log $cmd
            eval $cmd 

            # --------------------------------------------------------- #
            # Apply subcortical inverse to cortical parcellations.
            fileOut="${T1path}/T1_GM_parc_${parc}.nii.gz"

            cmd="fslmaths ${fileOut} -mas ${fileMas2} ${fileOut}"
            log $cmd
            eval $cmd 

            # --------------------------------------------------------- #
            # Generate a cerebellum mask using FSL's FIRST.

            FileIn="${T1path}/T1_fov_denoised.nii"
            FileRoot="${T1path}/subj_2_std_subc"
            FileMat="${T1path}/subj_2_std_subc_cort.mat"
            FileOut1="${T1path}/L_cerebellum.nii.gz"
            FileOut2="${T1path}/R_cerebellum.nii.gz"          

            FileModel1="${FSLDIR}/data/first/models_336_bin/intref_puta/L_Cereb.bmv"
            FileModel2="${FSLDIR}/data/first/models_336_bin/intref_puta/R_Cereb.bmv"
            FileRef1="${FSLDIR}/data/first/models_336_bin/05mm/L_Puta_05mm.bmv"
            FileRef2="${FSLDIR}/data/first/models_336_bin/05mm/R_Puta_05mm.bmv"

            cmd="first_flirt ${FileIn} ${FileRoot} -cort"
            log $cmd
            eval $cmd 

            cmd="run_first -i ${FileIn} \
            -t ${FileMat} \
            -o ${FileOut1} \
            -n 40 -m ${FileModel1} \
            -intref ${FileRef1}"
            log $cmd
            eval $cmd

            cmd="run_first -i ${FileIn} \
            -t ${FileMat} \
            -o ${FileOut2} \
            -n 40 -m ${FileModel2} \
            -intref ${FileRef2}"
            log $cmd
            eval $cmd

            # Clean up the edges of the cerebellar mask.
            cmd="first_boundary_corr -s ${FileOut1} \
            -i ${FileIn} \
            -b fast \
            -o ${FileOut1}"
            log $cmd
            eval $cmd    

            cmd="first_boundary_corr -s ${FileOut2} \
            -i ${FileIn} \
            -b fast \
            -o ${FileOut2}"
            log $cmd
            eval $cmd    

            # Add the left and right cerebellum masks together.
            FileOut="${T1path}/Cerebellum_bin.nii.gz"

            cmd="fslmaths ${FileOut1} -add ${FileOut2} ${FileOut}"
            log $cmd
            eval $cmd 

            # Fill holes in the mask
            cmd="fslmaths ${FileOut} -fillh ${FileOut}"
            log $cmd
            eval $cmd  

            # Invert the Cerebellum mask
            FileInv="${T1path}/Cerebellum_Inv.nii.gz"

            cmd="fslmaths ${FileOut1} -binv ${FileInv}"
            log $cmd
            eval $cmd       

            #-------------------------------------------------------------------------%    
            # Remove any parcellation contamination of the cerebellum.                             
            FileIn="${T1path}/T1_GM_parc_${parc}.nii.gz"
            
            cmd="fslmaths ${FileIn} -mas ${FileInv} ${FileIn}"
            log $cmd
            eval $cmd  

            #-------------------------------------------------------------------------%    
            # 07.25.2017 EJC Remove intermediates of the clean-up. 
            log "rm -vf ${FileRoot}"
            rm -vf ${FileRoot}*

            log "rm -v ${FileOut1}"
            rm -vf ${FileOut1}*

            log "rm -vf ${FileOut2}"
            rm -vf ${FileOut2}*

            log "rm -vf ${T1path}/L_cerebellum_*"
            rm -vf ${T1path}/L_cerebellum_*

            log "rm -vf ${T1path}/R_cerebellum_*"
            rm -vf ${T1path}/R_cerebellum_*  

            ## Add subcortical fsl parcellation to cortical parcellations
            if [[ ${configs_T1_addsubcort} ]] && [[ "${psubcortonly}" -eq 0 ]]; then 

                if [[ ! ${configs_T1_subcortUser} ]]; then  # default FSL subcortical

                    fileSubcort="${T1path}/T1_subcort_seg.nii.gz"

                else

                    nsubcor=0 

                    for ((ii=1; ii<=numParcs; ii++)); do  # exclude PARC0 - CSF - here

                        parcii="PARC${ii}"
                        parcii="${!parcii}"
                        psubcortonlyii="PARC${ii}psubcortonly"    
                        psubcortonlyii="${!psubcortonlyii}"

                        if [[ ${psubcortonlyii} -eq 1 ]]; then  # find subcortical-onnly parcellation

                            if [ ${nsubcor} -eq 0 ]; then
                                # check that parcellation is available in T1 space
                                fileSubcortUser="T1_parc_${parc}.nii.gz"

                                if [[ -f "${T1path}/fileSubcortUser" ]]; then

                                    fileSubcort="${T1path}/${fileSubcortUser}"
                                    nsubcort=1

                                fi
                            fi

                        fi 

                    done

                    if [ ${nsubcor} -eq 0 ]; then   # for-loop conditions not met so default to FSL subcortical 
                        fileSubcort="${T1path}/T1_subcort_seg.nii.gz"
                    fi

                fi
                
                
                log "ADD_SUBCORT_PARC using ${FileIn}"
                # call python script
                add_subcort_parc ${FileIn} ${pnodal} ${configs_T1_subcortUser}

            fi        

        fi 

        # 07.26.2017 EJC Dilate the final GM parcellations. 
        # NOTE: They will be used by f_functiona_connectivity
        #  to bring parcellations into epi space.

        if [[ ${psubcortonlyii} -ne 1 ]]; then

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
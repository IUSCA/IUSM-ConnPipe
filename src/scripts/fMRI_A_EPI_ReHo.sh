
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


log "# =========================================================="
log "# 9. EXTRAS - ReHo. "
log "# =========================================================="

PhReg_path="${EPIpath}/${regPath}"     

fileFC="${EPIpath}/rT1_brain_mask_FC.nii.gz"
fileT1brain="${T1path}/T1_brain.nii.gz"

path2ReHo="${PhReg_path}/${configs_ReHo_dirName}"
if [[ ! -d ${path2ReHo} ]]; then
    mkdir ${path2ReHo}
else 
    cmd="rm -rf ${path2ReHo}/"
    log $cmd
    rm -rf $path2ReHo/* 
fi 

if [ -z "${configs_ReHo_mask}" ]; then
    configs_ReHo_mask=${fileFC}
else
    if [[ ! -f ${configs_ReHo_mask} ]]; then
        log "ERROR - ${configs_ReHo_mask} not found"
        log "skipping further analysis"
        exit 1
    fi
fi

log "Using ${configs_ReHo_mask} as mask"

#Compute Kendall's W coefficients
cmd="3dReHo -prefix ${path2ReHo}/ReHo \
    -inset ${PhReg_path}/${configs_ReHo_input} \
    ${configs_ReHo_neigh} -mask ${configs_ReHo_mask}"
log $cmd
eval $cmd
#exitcode=$?

#Calculate mean and standard deviations of ReHo file created in 3dReHo Step
#within a mask and output to a text file M_SD.txt
cmd="3dmaskdump -noijk -mask ${configs_ReHo_mask} ${path2ReHo}/ReHo+orig \
     | 1d_tool.py -show_mmms -infile - >> ${path2ReHo}/M_SD.txt"
log $cmd
eval $cmd 

#Do some manipulations of the text file M_SD.txt and via a temporary file 
#M_SD2.txt, then save out the mean and standard deviations
#as variables (mean and sd)
cmd="sed 's/,//g' ${path2ReHo}/M_SD.txt > ${path2ReHo}/M_SD2.txt"
log $cmd
eval $cmd
cmd="mv ${path2ReHo}/M_SD2.txt ${path2ReHo}/M_SD.txt"
log $cmd
eval $cmd

mean=`cat ${path2ReHo}/M_SD.txt | grep 'mean' | awk '{printf $8}'`
echo "mean is $mean"
sd=`cat ${path2ReHo}/M_SD.txt | grep 'stdev' | awk '{printf $14}'`
echo "sd is $sd"

### NOTE about AFNI: cannot put -expr command into a string because the expression cannot be resolved

#Z-score Kendall's W values for use in group analyses
cmd="3dcalc -a ${path2ReHo}/ReHo+orig. -b ${configs_ReHo_mask} -expr '((a-'$mean')/'$sd'*b)' -prefix ${path2ReHo}/ReHo_normalized"
log $cmd 
log "Above command is executed directly from terminal"
3dcalc -a ${path2ReHo}/ReHo+orig. -b ${configs_ReHo_mask} -expr '((a-'$mean')/'$sd'*b)' -prefix ${path2ReHo}/ReHo_normalized


# Filter results through grey matter mask
fileGMmask="${EPIpath}/rT1_GM_mask.nii.gz"
cmd="3dcalc -a ${path2ReHo}/ReHo+orig. -b ${fileGMmask} -expr '(a*b)' -prefix ${path2ReHo}/ReHo_GM"
log $cmd
3dcalc -a ${path2ReHo}/ReHo+orig. -b ${fileGMmask} -expr '(a*b)' -prefix ${path2ReHo}/ReHo_GM 

cmd="3dcalc -a ${path2ReHo}/ReHo_normalized+orig. -b ${fileGMmask} -expr '(a*b)' -prefix ${path2ReHo}/ReHo_normalized_GM"
log $cmd 
3dcalc -a ${path2ReHo}/ReHo_normalized+orig. -b ${fileGMmask} -expr '(a*b)' -prefix ${path2ReHo}/ReHo_normalized_GM



#Convert files to nifti format
## 3dAFNItoNIFTI doesn't seem to work well if called outside of the data directory
cd ${path2ReHo}
cmd="3dAFNItoNIFTI ${path2ReHo}/ReHo+orig -prefix ReHo.nii"
log $cmd
eval $cmd
cmd="3dAFNItoNIFTI ${path2ReHo}/ReHo_normalized+orig -prefix ReHo_normalized.nii"
log $cmd
eval $cmd

cmd="3dAFNItoNIFTI ${path2ReHo}/ReHo_GM+orig -prefix ReHo_GM.nii"
log $cmd
eval $cmd
cmd="3dAFNItoNIFTI ${path2ReHo}/ReHo_normalized_GM+orig -prefix ReHo_normalized_GM.nii"
log $cmd
eval $cmd

cd ${EXEDIR}


## Transform output to MNI space 

fileIn=${path2ReHo}/ReHo_normalized.nii 
fileOut=${path2ReHo}/ReHo_normalized_MNI_${configs_ReHo_MNIres}mm.nii.gz
cmd="${EXEDIR}/src/func/transform_epi2MNI.sh \
    ${EPIpath} ${T1path}/registration \
    ${fileIn} ${fileOut} ${configs_ReHo_MNIres}"
log $cmd
eval $cmd

if [[ ! $? -eq 0 ]]; then
    log "ERROR - transformation of $fileIn to MNI space failed "
    exit 1
fi

if [[ "${configs_ReHo_MNIres}" != "1" ]] && [[ "${configs_ReHo_MNIres}" != "2" ]]; then
    # custom resolution defined by user
    log "WARNING - configs_ReHo_MNIres is not standard. Resampling will be performed"
    fileIn1mm=${path2ReHo}/ReHo_normalized_MNI_1mm.nii.gz
    cmd="mv ${fileOut} ${fileIn1mm}"
    log $cmd
    eval $cmd 

    # resample data
    cmd="${EXEDIR}/src/func/resample_MNIres.sh \
        ${fileIn1mm} ${fileOut} 1 ${configs_ReHo_MNIres}"
    log $cmd
    eval $cmd 

fi 


fileIn=${path2ReHo}/ReHo_normalized_GM.nii 
fileOut=${path2ReHo}/ReHo_normalized_GM_MNI_${configs_ReHo_MNIres}mm.nii.gz
cmd="${EXEDIR}/src/func/transform_epi2MNI.sh \
    ${EPIpath} ${T1path}/registration \
    ${fileIn} ${fileOut} ${configs_ReHo_MNIres}"
log $cmd
eval $cmd


if [[ ! $? -eq 0 ]]; then
    log "ERROR - transformation of $fileIn to MNI space failed "
    exit 1
fi


if [[ "${configs_ReHo_MNIres}" != "1" ]] && [[ "${configs_ReHo_MNIres}" != "2" ]]; then
    # custom resolution defined by user
    log "WARNING - configs_ReHo_MNIres is not standard. Resampling will be performed"
    fileIn1mm=${path2ReHo}/ReHo_normalized_GM_MNI_1mm.nii.gz
    cmd="mv ${fileOut} ${fileIn1mm}"
    log $cmd
    eval $cmd 

    # resample data
    cmd="${EXEDIR}/src/func/resample_MNIres.sh \
        ${fileIn1mm} ${fileOut} 1 ${configs_ReHo_MNIres}"
    log $cmd
    eval $cmd 

fi 

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
log "# 10. EXTRAS - ALFF. "
log "# =========================================================="

PhReg_path="${EPIpath}/${regPath}"     

fileFC="${EPIpath}/rT1_brain_mask_FC.nii.gz"
fileT1brain="${T1path}/T1_brain.nii.gz"

path2ALFF="${PhReg_path}/${configs_ALFF_dirName}"
if [[ ! -d ${path2ALFF} ]]; then
    mkdir ${path2ALFF}
else 
    cmd="rm -rf ${path2ALFF}/"
    log $cmd
    rm -rf $path2ALFF/* 
fi 

if [ -z "${configs_ALFF_mask}" ]; then
    configs_ALFF_mask=${fileFC}
else
    if [[ ! -f ${configs_ALFF_mask} ]]; then
        log "ERROR - ${configs_ALFF_mask} not found"
        log "skipping further analysis"
        exit 1
    fi
fi

log "Using ${configs_ALFF_mask} as mask"

#Run 3dRSFC with a 6 mm blur on input dataset
cmd="3dRSFC -prefix ${path2ALFF}/RSFC ${configs_ALFF_blur} \
    -mask ${configs_ALFF_mask} \
    -input ${PhReg_path}/${configs_ALFF_input} \
    ${configs_ALFF_bandpass} ${configs_ALFF_otherOptions}"
log $cmd
eval $cmd

#Calculate mean and standard deviations of ALFF and fALFF created in 3dRSFC Step
#within a mask and output to a text file M_SD.txt
cmd="3dmaskdump -noijk -mask ${configs_ALFF_mask} ${path2ALFF}/RSFC_ALFF+orig | 1d_tool.py -show_mmms -infile - >> ${path2ALFF}/M_SD1.txt"
log $cmd
eval $cmd

cmd="3dmaskdump -noijk -mask ${configs_ALFF_mask} ${path2ALFF}/RSFC_fALFF+orig | 1d_tool.py -show_mmms -infile - >> ${path2ALFF}/M_SD3.txt"
log $cmd
eval $cmd

#Do some manipulations of the text file M_SD1.txt and via a temporary file 
#M_SD2.txt, then save out the mean and standard deviations
#as variables (mean and sd)
#This is for the ALFF output
cmd="sed 's/,//g' ${path2ALFF}/M_SD1.txt > ${path2ALFF}/M_SD2.txt"
log $cmd
eval $cmd
cmd="mv ${path2ALFF}/M_SD2.txt ${path2ALFF}/M_SD1.txt"
log $cmd
eval $cmd

mean=`cat ${path2ALFF}/M_SD1.txt | grep 'mean' | awk '{printf $8}'`
echo "mean is $mean"
sd=`cat ${path2ALFF}/M_SD1.txt | grep 'stdev' | awk '{printf $14}'`
echo "sd is $sd"

#Z-score ALFF values for use in group analyses
cmd="3dcalc -a ${path2ALFF}/RSFC_ALFF+orig. -b ${configs_ALFF_mask} -expr '((a-'$mean')/'$sd'*b)' -prefix ${path2ALFF}/RSFC_ALFF_normalized"
log $cmd
3dcalc -a ${path2ALFF}/RSFC_ALFF+orig. -b ${configs_ALFF_mask} -expr '((a-'$mean')/'$sd'*b)' -prefix ${path2ALFF}/RSFC_ALFF_normalized

#Do some manipulations of the text file M_SD3.txt and via a temporary file 
#M_SD4.txt, then save out the mean and standard deviations
#as variables (mean and sd)
#This is for the fALFF output
cmd="sed 's/,//g' ${path2ALFF}/M_SD3.txt > ${path2ALFF}/M_SD2.txt"
log $cmd
eval $cmd
cmd="mv ${path2ALFF}/M_SD2.txt ${path2ALFF}/M_SD3.txt"
log $cmd
eval $cmd

mean=`cat ${path2ALFF}/M_SD3.txt | grep 'mean' | awk '{printf $8}'`
echo "mean is $mean"
sd=`cat ${path2ALFF}/M_SD3.txt | grep 'stdev' | awk '{printf $14}'`
echo "sd is $sd"

#Z-score fALFF values for use in group analyses
cmd="3dcalc -a ${path2ALFF}/RSFC_fALFF+orig. -b ${configs_ALFF_mask} -expr '((a-'$mean')/'$sd'*b)' -prefix ${path2ALFF}/RSFC_fALFF_normalized"
log $cmd
3dcalc -a ${path2ALFF}/RSFC_fALFF+orig. -b ${configs_ALFF_mask} -expr '((a-'$mean')/'$sd'*b)' -prefix ${path2ALFF}/RSFC_fALFF_normalized


#Filter results through grey matter mask 
fileGMmask="${EPIpath}/rT1_GM_mask.nii.gz"
cmd="3dcalc -a ${path2ALFF}/RSFC_ALFF+orig. -b ${fileGMmask} -expr '(a*b)' -prefix ${path2ALFF}/RSFC_ALFF_GM"
log $cmd
3dcalc -a ${path2ALFF}/RSFC_ALFF+orig. -b ${fileGMmask} -expr '(a*b)' -prefix ${path2ALFF}/RSFC_ALFF_GM

cmd="3dcalc -a ${path2ALFF}/RSFC_ALFF_normalized+orig. -b ${fileGMmask} -expr '(a*b)' -prefix ${path2ALFF}/RSFC_ALFF_normalized_GM"
log $cmd
3dcalc -a ${path2ALFF}/RSFC_ALFF_normalized+orig. -b ${fileGMmask} -expr '(a*b)' -prefix ${path2ALFF}/RSFC_ALFF_normalized_GM

cmd="3dcalc -a ${path2ALFF}/RSFC_fALFF+orig. -b ${fileGMmask} -expr '(a*b)' -prefix ${path2ALFF}/RSFC_fALFF_GM"
log $cmd
3dcalc -a ${path2ALFF}/RSFC_fALFF+orig. -b ${fileGMmask} -expr '(a*b)' -prefix ${path2ALFF}/RSFC_fALFF_GM

cmd="3dcalc -a ${path2ALFF}/RSFC_fALFF_normalized+orig. -b ${fileGMmask} -expr '(a*b)' -prefix ${path2ALFF}/RSFC_fALFF_normalized_GM"
log $cmd
3dcalc -a ${path2ALFF}/RSFC_fALFF_normalized+orig. -b ${fileGMmask} -expr '(a*b)' -prefix ${path2ALFF}/RSFC_fALFF_normalized_GM




#Convert files to nifti format
## 3dAFNItoNIFTI doesn't seem to work well if called outside of the data directory
cd ${path2ALFF}
cmd="3dAFNItoNIFTI ${path2ALFF}/RSFC_ALFF+orig -prefix RSFC_ALFF.nii"
log $cmd
eval $cmd
cmd="3dAFNItoNIFTI ${path2ALFF}/RSFC_ALFF_normalized+orig -prefix RSFC_ALFF_normalized.nii"
log $cmd
eval $cmd
cmd="3dAFNItoNIFTI ${path2ALFF}/RSFC_fALFF+orig -prefix RSFC_fALFF.nii"
log $cmd
eval $cmd
cmd="3dAFNItoNIFTI ${path2ALFF}/RSFC_fALFF_normalized+orig -prefix RSFC_fALFF_normalized.nii"
log $cmd
eval $cmd

cmd="3dAFNItoNIFTI ${path2ALFF}/RSFC_ALFF_GM+orig -prefix RSFC_ALFF_GM.nii"
log $cmd
eval $cmd
cmd="3dAFNItoNIFTI ${path2ALFF}/RSFC_ALFF_normalized_GM+orig -prefix RSFC_ALFF_normalized_GM.nii"
log $cmd
eval $cmd
cmd="3dAFNItoNIFTI ${path2ALFF}/RSFC_fALFF_GM+orig -prefix RSFC_fALFF_GM.nii"
log $cmd
eval $cmd
cmd="3dAFNItoNIFTI ${path2ALFF}/RSFC_fALFF_normalized_GM+orig -prefix RSFC_fALFF_normalized_GM.nii"
log $cmd
eval $cmd

cd ${EXEDIR}


## Transform output to MNI space 
fileIn=${path2ALFF}/RSFC_ALFF_normalized.nii
fileOut=${path2ALFF}/RSFC_ALFF_normalized_MNI_${configs_ALFF_MNIres}mm.nii.gz

cmd="${EXEDIR}/src/func/transform_epi2MNI.sh \
    ${EPIpath} ${T1path}/registration \
    ${fileIn} ${fileOut} ${configs_ALFF_MNIres}"
log $cmd
eval $cmd

if [[ ! $? -eq 0 ]]; then
    log "ERROR - transformation of $fileIn to MNI space failed "
    exit 1
fi

if [[ "${configs_ALFF_MNIres}" != "1" ]] && [[ "${configs_ALFF_MNIres}" != "2" ]]; then
    # custom resolution defined by user
    log "WARNING - configs_ALFF_MNIres is not standard. Resampling will be performed"
    fileIn1mm=${path2ALFF}/RSFC_ALFF_normalized_MNI_1mm.nii.gz
    cmd="mv ${fileOut} ${fileIn1mm}"
    log $cmd
    eval $cmd 

    # resample data
    cmd="${EXEDIR}/src/func/resample_MNIres.sh \
        ${fileIn1mm} ${fileOut} 1 ${configs_ALFF_MNIres}"
    log $cmd
    eval $cmd 

fi 

## Transform output to MNI space 
fileIn=${path2ALFF}/RSFC_fALFF_normalized.nii
fileOut=${path2ALFF}/RSFC_fALFF_normalized_MNI_${configs_ALFF_MNIres}mm.nii.gz
cmd="${EXEDIR}/src/func/transform_epi2MNI.sh \
    ${EPIpath} ${T1path}/registration \
    ${fileIn} ${fileOut} ${configs_ALFF_MNIres}"
log $cmd
eval $cmd

if [[ ! $? -eq 0 ]]; then
    log "ERROR - transformation of $fileIn to MNI space failed "
    exit 1
fi

if [[ "${configs_ALFF_MNIres}" != "1" ]] && [[ "${configs_ALFF_MNIres}" != "2" ]]; then
    # custom resolution defined by user
    log "WARNING - configs_ALFF_MNIres is not standard. Resampling will be performed"
    fileIn1mm=${path2ALFF}/RSFC_fALFF_normalized_MNI_1mm.nii.gz
    cmd="mv ${fileOut} ${fileIn1mm}"
    log $cmd
    eval $cmd 

    # resample data
    cmd="${EXEDIR}/src/func/resample_MNIres.sh \
        ${fileIn1mm} ${fileOut} 1 ${configs_ALFF_MNIres}"
    log $cmd
    eval $cmd 

fi 

fileIn=${path2ALFF}/RSFC_ALFF_normalized_GM.nii
fileOut=${path2ALFF}/RSFC_ALFF_normalized_GM_MNI_${configs_ALFF_MNIres}mm.nii.gz

cmd="${EXEDIR}/src/func/transform_epi2MNI.sh \
    ${EPIpath} ${T1path}/registration \
    ${fileIn} ${fileOut} ${configs_ALFF_MNIres}"
log $cmd
eval $cmd

if [[ ! $? -eq 0 ]]; then
    log "ERROR - transformation of $fileIn to MNI space failed "
    exit 1
fi

if [[ "${configs_ALFF_MNIres}" != "1" ]] && [[ "${configs_ALFF_MNIres}" != "2" ]]; then
    # custom resolution defined by user
    log "WARNING - configs_ALFF_MNIres is not standard. Resampling will be performed"
    fileIn1mm=${path2ALFF}/RSFC_ALFF_normalized_GM_MNI_1mm.nii.gz
    cmd="mv ${fileOut} ${fileIn1mm}"
    log $cmd
    eval $cmd 

    # resample data
    cmd="${EXEDIR}/src/func/resample_MNIres.sh \
        ${fileIn1mm} ${fileOut} 1 ${configs_ALFF_MNIres}"
    log $cmd
    eval $cmd 

fi 

## Transform output to MNI space 
fileIn=${path2ALFF}/RSFC_fALFF_normalized_GM.nii
fileOut=${path2ALFF}/RSFC_fALFF_normalized_GM_MNI_${configs_ALFF_MNIres}mm.nii.gz
cmd="${EXEDIR}/src/func/transform_epi2MNI.sh \
    ${EPIpath} ${T1path}/registration 
    ${fileIn} ${fileOut} ${configs_ALFF_MNIres}"
log $cmd
eval $cmd

if [[ ! $? -eq 0 ]]; then
    log "ERROR - transformation of $fileIn to MNI space failed "
    exit 1
fi

if [[ "${configs_ALFF_MNIres}" != "1" ]] && [[ "${configs_ALFF_MNIres}" != "2" ]]; then
    # custom resolution defined by user
    log "WARNING - configs_ALFF_MNIres is not standard. Resampling will be performed"
    fileIn1mm=${path2ALFF}/RSFC_fALFF_normalized_GM_MNI_1mm.nii.gz
    cmd="mv ${fileOut} ${fileIn1mm}"
    log $cmd
    eval $cmd 

    # resample data
    cmd="${EXEDIR}/src/func/resample_MNIres.sh \
        ${fileIn1mm} ${fileOut} 1 ${configs_ALFF_MNIres}"
    log $cmd
    eval $cmd 

fi 
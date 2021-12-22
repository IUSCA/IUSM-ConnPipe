
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

#Run 3dRSFC with a 6 mm blur on input dataset
cmd="3dRSFC -prefix ${path2ALFF}/RSFC -blur 6 -mask ${fileFC} -input ${PhReg_path}/${configs_ALFF_input} 0.01 0.1"
log $cmd
eval $cmd

#Calculate mean and standard deviations of ALFF and fALFF created in 3dRSFC Step
#within a mask and output to a text file M_SD.txt
cmd="3dmaskdump -noijk -mask ${fileFC} ${path2ALFF}/RSFC_ALFF+orig | 1d_tool.py -show_mmms -infile - >> ${path2ALFF}/M_SD1.txt"
log $cmd
eval $cmd

cmd="3dmaskdump -noijk -mask ${fileFC} ${path2ALFF}/RSFC_fALFF+orig | 1d_tool.py -show_mmms -infile - >> ${path2ALFF}/M_SD3.txt"
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
cmd="3dcalc -a ${path2ALFF}/RSFC_ALFF+orig. -b ${fileFC} -expr '((a-'$mean')/'$sd'*b)' -prefix ${path2ALFF}/RSFC_ALFF_normalized"
log $cmd
3dcalc -a ${path2ALFF}/RSFC_ALFF+orig. -b ${fileFC} -expr '((a-'$mean')/'$sd'*b)' -prefix ${path2ALFF}/RSFC_ALFF_normalized

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
cmd="3dcalc -a ${path2ALFF}/RSFC_fALFF+orig. -b ${fileFC} -expr '((a-'$mean')/'$sd'*b)' -prefix ${path2ALFF}/RSFC_fALFF_normalized"
log $cmd
3dcalc -a ${path2ALFF}/RSFC_fALFF+orig. -b ${fileFC} -expr '((a-'$mean')/'$sd'*b)' -prefix ${path2ALFF}/RSFC_fALFF_normalized

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
cd ${EXEDIR}

#Filter results through grey matter mask if you so desire
#cp "$rootdir"/"$i"/EP1/rT1_GM_mask.nii.gz "$rootdir"/"$i"/EP1/HMPreg/meanPhysReg/rT1_GM_mask.nii.gz
#3dcalc -a "$i"_RSFC_ALFF+orig. -b rT1_GM_mask.nii.gz -expr '(a*b)' -prefix "$i"_RSFC_ALFF_GM
#3dcalc -a "$i"_RSFC_ALFF_normalized+orig. -b rT1_GM_mask.nii.gz -expr '(a*b)' -prefix "$i"_RSFC_ALFF_normalized_GM
#3dcalc -a "$i"_RSFC_fALFF+orig. -b rT1_GM_mask.nii.gz -expr '(a*b)' -prefix "$i"_RSFC_fALFF_GM
#3dcalc -a "$i"_RSFC_fALFF_normalized+orig. -b rT1_GM_mask.nii.gz -expr '(a*b)' -prefix "$i"_RSFC_fALFF_normalized_GM


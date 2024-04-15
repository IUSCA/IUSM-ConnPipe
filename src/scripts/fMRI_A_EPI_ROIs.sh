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

msg2file "# =========================================================="
msg2file "# 8. ROIs. "
msg2file "# =========================================================="

if ${configs_T1_addsubcort} && ! ${configs_T1_subcortUser}; then  # default FSL subcortical

    if [[ -e "${EPIrun_out}/rT1_GM_parc_FSLsubcort_clean.nii.gz" ]]; then 
        log "configs_T1_subcortUser is ${configs_T1_subcortUser} - using FSL default subcortical"
        
        export numParcs=$(($numParcs+1))

        parcFSL=PARC$numParcs
        parcFSLcort=PARC${numParcs}pcort
        parcFSLnodal=PARC${numParcs}pnodal
        parcFSLsubcortonly=PARC${numParcs}psubcortonly
        parcFSLcrblmonly=PARC${numParcs}pcrblmonly

        export "${parcFSL}"="FSLsubcort";
        export "${parcFSLcort}"=0;
        export "${parcFSLnodal}"=1;
        export "${parcFSLsubcortonly}"=1;
        export "${parcFSLcrblmonly}"=0;
    fi
fi


log "nR is ${nR}"

# Identify what files to load

if [[ ${configs_scrub} == "no_scrub" ]]; then

    fileIn="${NuisancePhysReg_out}/NuisanceRegression_${nR}.npz"

elif [[ ${configs_scrub} == "stat_DVARS" ]] || [[ ${configs_scrub} == "fsl_fd_dvars" ]] ; then
    if ! ${configs_EPI_despike}; then
        fileIn="${NuisancePhysReg_out}/NuisanceRegression_${nR}_scrubbed.npz"
    else 
        fileIn="${NuisancePhysReg_out}/NuisanceRegression_${nR}.npz"
    fi 
fi 

log --no-datetime "Computing ROI Time Series on ${fileIn}"

checkisfile ${fileIn}    

cmd="python ${EXEDIR}/src/func/ROI_TS.py ${fileIn}"
log $cmd
eval $cmd 2>&1 | tee -a ${logfile_name}.log

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

PhReg_path="${EPIrun_out}/${regPath}"   

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

cmd="python ${EXEDIR}/src/func/ROI_TS.py ${PhReg_path}"
log $cmd
eval $cmd

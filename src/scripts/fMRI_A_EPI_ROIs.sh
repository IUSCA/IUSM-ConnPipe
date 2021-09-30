
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
log "# 8. ROIs. "
log "# =========================================================="

PhReg_path="${EPIpath}/${regPath}"     


## To do: make sure needed files exist before entering python script

cmd="python ${EXEDIR}/src/func/ROI_TS.py ${PhReg_path}"
log $cmd
eval $cmd

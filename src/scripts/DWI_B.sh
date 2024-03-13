#!/bin/bash
#
# Script: DWI_A adaptaion from Matlab script 
#
###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

###############################################################################
# Load IU Quartz supercomuter modules
module load mrtrix3/3.0.2

# define the number of threads you want mrtrix to use
    # setting environmentally to avoid accidentally using all cores
    export MRTRIX_NTHREADS=$configs_DWI_nthreads

############################################################################### 

if [[ -d ${DWIpath} ]]; then

    log "DWI_B processing for subject ${SUBJ}"
    
    # set paths
    export path_DWI_EDDY="${DWIpath}/EDDY"
    export path_DWI_DTIfit="${DWIpath}/DTIfit"
    export path_DWI_mrtrix="${DWIpath}/MRtrix"
    export path_DWI_matrices="${DWIpath}/CONNmats"

    if [[ ! -d "${path_DWI_EDDY}" ]]; then
        log "Path to EDDY directory does not exist. Exiting..."
        exit 1
    else 
        if [[ ! -d "${path_DWI_DTIfit}" ]]; then
            log "Path to DTIfit directory does not exist. Exiting..."
            exit 1
        fi
    fi
######################################################################################
    #### Registration of B0 to T1
    if ${flags_DWI_regT1}; then

        cmd="${EXEDIR}/src/scripts/DWI_B_regT12DWI.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at DWI_B_regT12DWI. exiting."
            exit 1
        fi  
    fi
######################################################################################
    #### MRtrix
    if ${flags_DWI_MRtrix}; then

        cmd="${EXEDIR}/src/scripts/DWI_B_MRtrix.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at DWI_B_MRtrix. exiting."
            exit 1
        fi  
    fi
######################################################################################
    #### Connectivity Matrix
    if ${flags_DWI_connMatrix}; then

        cmd="${EXEDIR}/src/scripts/DWI_B_connMatrix.sh"
        echo $cmd
        eval $cmd
        exitcode=$?

        if [[ ${exitcode} -ne 0 ]] ; then
            echoerr "problem at DWI_B_connMatrix. exiting."
            exit 1
        fi  
    fi

else 

    log "WARNING Subject DWI directory does not exist; skipping DWI processing for subject ${SUBJ}"

fi 
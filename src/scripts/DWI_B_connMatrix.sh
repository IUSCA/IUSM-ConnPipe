
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

############################################################################### 



############################################################################### 


echo "=================================="
echo "3. Connectivity Matrix Assembly"
echo "=================================="


if [[ ! -d "${path_DWI_matrices}" ]]; then
    cmd="mkdir ${path_DWI_matrices}"
    log $cmd
    eval $cmd
fi 

# check paths
log "path_DWI_EDDY is ${path_DWI_EDDY}"
log "path_DWI_DTIfit is ${path_DWI_DTIfit}"
log "path_DWI_mrtrix is ${path_DWI_mrtrix}"
log "path_DWI_matrices is ${path_DWI_matrices}"

fileFiltStreamlines="${path_DWI_mrtrix}/1m_sift_streamlines.tck"


for ((p=1; p<=numParcs; p++)); do  # exclude PARC0 - CSF - here

    parc="PARC$p"
    parc="${!parc}"
    pcort="PARC${p}pcort"
    pcort="${!pcort}"  
    pnodal="PARC${p}pnodal"  
    pnodal="${!pnodal}"                        

    echo "${p}) ${parc} parcellation"

    if [ ${pnodal} -eq 1 ]; then  
        echo " -- Nodal parcellation: ${pnodal}" 
        
        # transformation from T1 to epi space
        fileparc="${DWIpath}/rT1_GM_parc_${parc}.nii.gz"
        fileConnMatrix="${path_DWI_matrices}/1M_2radial_density_${parc}.csv"

        # CONFIG assignment_radial_search can be user set
        # CONFIG scale_invnodevol: other options are available for edge assignment
        # CONFIG symmetric could be optional, but its good practive to have it
        # CONFIG: zero_diagonal can be optional

        cmd="tck2connectome -assignment_radial_search 2 \
            -scale_invnodevol -symmetric \
            -zero_diagonal \
            -force ${fileFiltStreamlines} ${fileparc} ${fileConnMatrix}"
        log $cmd
        eval $cmd
    else
        echo " -- Not a nodal parcellation"
    fi
done
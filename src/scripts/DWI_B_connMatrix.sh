
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

# set paths
path_DWI_EDDY="${DWIpath}/EDDY"
path_DWI_DTIfit="${DWIpath}/DTIfit"
path_DWI_mrtrix="${DWIpath}/MRtrix"
path_DWI_matrices="${DWIpath}/CONNmats"


if [[ ! -d "${path_DWI_matrices}" ]]; then
    cmd="mkdir ${path_DWI_matrices}"
    log $cmd
    eval $cmd
fi 

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
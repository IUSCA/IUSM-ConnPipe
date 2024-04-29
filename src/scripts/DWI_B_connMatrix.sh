
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

msg2file "=================================="
msg2file "3. Connectivity Matrix Assembly"
msg2file "=================================="


if [[ ! -d "${path_DWI_matrices}" ]]; then
    cmd="mkdir ${path_DWI_matrices}"
    log $cmd
    eval $cmd
fi 

# check paths
log --no-datetime "path_DWI_EDDY is ${path_DWI_EDDY}"
log --no-datetime "path_DWI_DTIfit is ${path_DWI_DTIfit}"
log --no-datetime "path_DWI_mrtrix is ${path_DWI_mrtrix}"
log --no-datetime "path_DWI_matrices is ${path_DWI_matrices}"

fileFiltStreamlines="${path_DWI_mrtrix}/${configs_DWI_sift_term_number}_sift_streamlines.tck"

cntcort=0
cntsubc=0
cntcrblm=0
 echo "Concatenating Parcellation Images..."
 pcname=""
for ((p=1; p<=numParcs; p++)); do  # exclude PARC0 - CSF - here

    parc="PARC$p"
    parc="${!parc}"
    pcort="PARC${p}pcort"
    pcort="${!pcort}"  
    pnodal="PARC${p}pnodal"  
    pnodal="${!pnodal}"   
    pcrblm="PARC${p}pcrblmonly"
    pcrblm="${!pcrblm}"  
    psubc="PARC${p}psubcortonly"
    psubc="${!psubc}" 

    if [[ "${pnodal}" -eq 1 ]]; then
        if [[ "${pcort}" -eq 1 ]] && [[ $cntcort -eq 0 ]]; then   
            echo " -- Cortical parcellation: ${parc}"
            pcname="${pcname}_${parc}"
            # 
            fileparcCORT="${DWIpath}/rT1_GM_parc_${parc}.nii.gz"
            ((cntcort++))
        elif [[ "${psubc}" -eq 1 ]] && [[ $cntsubc -eq 0 ]]; then
            echo " -- Subcortical parcellation: ${parc}" 
            pcname="${pcname}_${parc}"
            # 
            fileparcSUBC="${DWIpath}/rT1_GM_parc_${parc}.nii.gz"
            ((cntsubc++))
        elif [[ "${pcrblm}" -eq 1 ]] && [[ $cntcrblm -eq 0 ]]; then
            echo " -- Cerebellar parcellation: ${parc}" 
            pcname="${pcname}_${parc}"
            # 
            fileparcCRBLM="${DWIpath}/rT1_parc_${parc}.nii.gz"
            ((cntcrblm++))
        fi
    else
        echo " -- Not a nodal parcellation"
    fi
done

if [[ "${cntsubc}" -eq 0 ]] && [[ $configs_T1_subcortUser == false ]]; then
    echo " -- Subcortical parcellation: FSLsubcort" 
    pcname="${pcname}_FSLsubcort"
    # 
    fileparcSUBC="${DWIpath}/rT1_GM_parc_FSLsubcort.nii.gz"
    ((cntsubc++))
fi

FileIn="${path_DWI_matrices}/rT1${pcname}.nii.gz"
cmd="cp ${fileparcCORT} ${FileIn}"
log $cmd
eval $cmd 

if [[ "${cntsubc}" -ne 0 ]]
    # call python script
    cmd="python ${EXEDIR}/src/func/add_parc.py \
        ${FileIn} 1 \
        ${fileparcSUBC}"
    log $cmd
    eval $cmd 2>&1 | tee -a ${logfile_name}.log
fi
if [[ "${cntcrblm}" -ne 0 ]]
    cmd="python ${EXEDIR}/src/func/add_parc.py \
        ${FileIn} 0 \
        ${fileparcCRBLM}"
    log $cmd
    eval $cmd 2>&1 | tee -a ${logfile_name}.log
fi

fileConnMatrix="${path_DWI_matrices}/${configs_DWI_sift_term_number}_2radial_density${pcname}.csv"

# CONFIG assignment_radial_search can be user set
# CONFIG scale_invnodevol: other options are available for edge assignment
# CONFIG symmetric could be optional, but its good practive to have it
# CONFIG: zero_diagonal can be optional

if ${flag_HPC_modules}; then
    echo "Loading HPC module ${mrtrix}"
    module load ${mrtrix}
fi 

cmd="tck2connectome -assignment_radial_search 2 \
    -scale_invnodevol -symmetric \
    -zero_diagonal \
    -force ${fileFiltStreamlines} ${FileIn} ${fileConnMatrix}"
log $cmd
eval $cmd

 
if ${flag_HPC_modules}; then
    echo "Unloading HPC python loaded with MRtrix"
    module unload ${mrtrix} 
fi 

py_ver=$(python --version)
log "****** ${py_ver} ******"
py_which=$(which python)
log "****** ${py_which} ******"
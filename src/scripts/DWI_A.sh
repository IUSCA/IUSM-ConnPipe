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


if [[ -d ${DWIpath_raw} ]]; then

    log "DWI_A processing for subject ${SUBJ}"
    log "${DWIpath_raw} "

    echo "Checking for phase encoding AP-PA series"
    # Generate list of EPI scan directories
    declare -a dwiList
    while IFS= read -r -d $'\0' REPLY; do 
        dwiList+=( "$REPLY" )
    done < <(find ${DWIpath_raw} -maxdepth 1 -type f -iname "*_dir-*nii.gz" -print0 | sort -z)
    
    if [ ${#dwiList[@]} -eq 0 ]; then 
        echo "No raw dwi files with _dir- tag found for subject $SUBJ. Check that dir- Phase Encoding is in bids naming."
        exit 1
    elif [ ${#dwiList[@]} -gt 1 ]; then
        echo "Multiple raw dwi runs found for subject $SUBJ."
        echo "There are ${#dwiList[@]} DWI-series "
    else
        echo "Single raw dwi with _dir tag found for subject $SUBJ."
        echo "There are ${#dwiList[@]} DWI-series "
    fi
   
    # Check phase encoding and volume counts
    log "Checking DWI data..."
    for ((i=0; i<${#dwiList[@]}; i++)); do
        log --no-datetime "File: ${dwiList[$i]}"

        if [[ "${dwiList[$i]}" == *"_acq-"* ]]; then
            acqtype=$(echo "${dwiList[$i]}" | grep -oP '_acq-\K[^_]+')
            log --no-datetime " acq- tag in file: ${acqtype}"
            
            pedir=$(echo "${dwiList[$i]}" | grep -oP '_dir-\K[^_]+')
            log --no-datetime " dir- tag in file: ${pedir}"

            if [[ "${acqtype}" == "b0" ]] && [[ $pedir == "PA" ]]; then
                b0PA="${dwiList[$i]}"
                log --no-datetime "File set as: b0_PA"
                unset acqtype
                unset pedir
            else
                log --no-datetime "File NOT set." 
                unset acqtype
                unset pedir
            fi

        else
            log --no-datetime " No acq- tag in file name."

            pedir=$(echo "${dwiList[$i]}" | grep -oP '_dir-\K[^_]+')
            log --no-datetime " dir- tag in file: ${pedir}"

            if [[ $pedir == "PA" ]]; then
                PA="${dwiList[$i]}"
                log --no-datetime "File set as: PA"
                unset acqtype
                unset pedir
            elif [[ $pedir == "AP" ]]; then
                AP="${dwiList[$i]}"
                log --no-datetime "File set as: AP"
                unset acqtype
                unset pedir
            else
                log --no-datetime "File NOT set. Unrecognized phase encoding." 
                unset acqtype
                unset pedir
            fi
        fi
    done

    if [ -n "$AP" ]; then
        FileRaw="${AP%???????}"

        PhaseEncodingDirection=`cat ${FileRaw}.json | ${EXEDIR}/src/func/jq-linux64 '.PhaseEncodingDirection'`
        echo "PhaseEncodingDirection from ${FileRaw}.json is ${PhaseEncodingDirection}"  

            if [[ "${PhaseEncodingDirection}" == '"j-"' ]]; then
                TotalReadoutTimeAP=`cat ${FileRaw}.json | ${EXEDIR}/src/func/jq-linux64 '.TotalReadoutTime'`
                echo "TotalReadoutTime from ${FileRaw}.json is ${TotalReadoutTimeAP}"
                export APline="0 -1 0 ${TotalReadoutTimeAP}"   
            else
                log "Mismatch between dir- and json coded phase encoding. Double check data. Exiting..."
                exit 1
            fi        

        if [ -n "$PA" ]; then
            FileRawPA="${PA%???????}"
            export rtag=1

            PhaseEncodingDirection=`cat ${FileRawPA}.json | ${EXEDIR}/src/func/jq-linux64 '.PhaseEncodingDirection'`
            echo "PhaseEncodingDirection from ${FileRawPA}.json is ${PhaseEncodingDirection}"  

            if [[ "${PhaseEncodingDirection}" == '"j"' ]]; then
                TotalReadoutTimePA=`cat ${FileRawPA}.json | ${EXEDIR}/src/func/jq-linux64 '.TotalReadoutTime'`
                echo "TotalReadoutTime from ${FileRawPA}.json is ${TotalReadoutTimePA}"

                if [ "$TotalReadoutTimeAP" != "$TotalReadoutTimePA" ]; then
                    log "Unequal TotalReadoutTime in AP vs. PA json files. Check data. Exiting..."
                    exit 1
                fi
                export PAline="0 1 0 ${TotalReadoutTimePA}"  

            else
                log "Mismatch between dir- and json coded phase encoding. Double check data. Exiting..."
                exit 1
            fi  

        elif [ -n  "$b0PA" ]; then
            FileRawb0="$b0PA%???????"
            export rtag=2

            PhaseEncodingDirection=`cat ${FileRawb0}.json | ${EXEDIR}/src/func/jq-linux64 '.PhaseEncodingDirection'`
            echo "PhaseEncodingDirection from ${FileRawb0}.json is ${PhaseEncodingDirection}"  

            if [[ "${PhaseEncodingDirection}" == '"j"' ]]; then
                TotalReadoutTimeb0PA=`cat ${FileRawb0}.json | ${EXEDIR}/src/func/jq-linux64 '.TotalReadoutTime'`
                echo "TotalReadoutTime from ${FileRawb0}.json is ${TotalReadoutTimeb0PA}"

                if [ "$TotalReadoutTimeAP" != "$TotalReadoutTimeb0PA" ]; then
                    log "Unequal TotalReadoutTime in AP vs. b0PA json files. Check data. Exiting..."
                    exit 1
                fi
                export PAline="0 1 0 ${TotalReadoutTimeb0PA}"  

            else
                log "Mismatch between dir- and json coded phase encoding. Double check data. Exiting..."
                exit 1
            fi  

        else
            export rtag=3
        fi

    else
        log " No AP phase encoding run found. Exitings ..."
        exit 1
    fi

else 

    log "WARNING Subject raw DWI directory does not exist; skipping DWI processing for subject ${SUBJ}"

fi 

######################################################################################

msg2file "=================================="
msg2file "0.5. Bvec & Bval File Format"
msg2file "=================================="  

export fileBval="${FileRaw}.bval"
export fileBvec="${FileRaw}.bvec"
export fileNifti="${FileRaw}.nii.gz"
export fileJson="${FileRaw}.json"

if [[ ! -e "${fileBval}" ]] && [[ ! -e "${fileBvec}" ]]; then
    log "WARNING Bvec and/or Bval files do not exist. Skipping further analyses"
    exit 1
else
    cmd="python ${EXEDIR}/src/func/read_bvals_bvecs.py \
     ${fileBval} ${fileBvec} ${fileNifti} ${DWIpath}"
    log $cmd
    eval $cmd

    export fileBval="${DWIpath}/0_DWI.bval"
    export fileBvec="${DWIpath}/0_DWI.bvec"
fi 

if [[ "$rtag" -eq 1 ]]; then
    export fileBvalPA="${FileRawPA}.bval"
    export fileBvecPA="${FileRawPA}.bvec"
    export fileNiftiPA="${FileRawPA}.nii.gz"

    if [[ ! -e "${fileBvalPA}" ]] && [[ ! -e "${fileBvecPA}" ]]; then
        log "WARNING Bvec and/or Bval PA files do not exist. Skipping further analyses"
        exit 1
    else
        cmd="python ${EXEDIR}/src/func/read_bvals_bvecs.py \
         ${fileBvalPA} ${fileBvecPA} ${fileNiftiPA} ${DWIpath} "PA""
        log $cmd
        eval $cmd

        export fileBvalPA="${DWIpath}/0_DWI_PA.bval"
        export fileBvecPA="${DWIpath}/0_DWI_PA.bvec"
    fi

elif [[ "$rtag" -eq 2 ]]; then
    export fileBvalb0PA="${DWIpath}/0_DWI_b0PA.bval"
    export fileBvecb0PA="${DWIpath}/0_DWI_b0PA.bvec"
    export fileNiftib0PA="${FileRawb0}.nii.gz"

    log "Creating dummy Bvec and/or Bval files ${DWIpath}/${fileBvalb0PA} and ${DWIpath}/${fileBvecb0PA}"
    # find the number of B0's as the 4th dimension
    numB0=$(fslinfo ${fileNiftib0PA} | awk '/^dim4/' | awk '{split($0,a," "); {print a[2]}}')
    log "There is/are ${numB0} B0 in ${fileNiftib0PA}"

    # create dummy B0 files
    dummy_bvec=`echo -e '0 \t 0 \t  0 \t'` 
    for ((k=0; k<${numB0}; k++)); do
        echo ${dummy_bvec} >> ${DWIpath}/${fileBvecb0PA}
        echo "0" >> ${DWIpath}/${fileBvalb0PA}
    done
fi
   
######################################################################################
    #### Topup field estimation.
export TOPUPpath="${DWIpath}/TOPUP"
if ${flags_DWI_topup}; then
    
    cmd="${EXEDIR}/src/scripts/DWI_A_topup.sh"
    echo $cmd
    eval $cmd
    exitcode=$?

    if [[ ${exitcode} -ne 0 ]] ; then
        echoerr "problem at DWI_A_topup. exiting."
        exit 1
    fi  
fi

######################################################################################
    #### FSL EDDY
export EDDYpath="${DWIpath}/EDDY"
if ${flags_DWI_eddy}; then

    cmd="${EXEDIR}/src/scripts/DWI_A_eddy.sh"
    echo $cmd
    eval $cmd
    exitcode=$?

    if [[ ${exitcode} -ne 0 ]] ; then
        echoerr "problem at DWI_A_eddy. exiting."
        exit 1
    fi  
fi

######################################################################################
    #### DTIfit
export DTpath="${DWIpath}/DTIfit"    
if ${flags_DWI_DTIfit}; then

    cmd="${EXEDIR}/src/scripts/DWI_A_DTIfit.sh"
    echo $cmd
    eval $cmd
    exitcode=$?

    if [[ ${exitcode} -ne 0 ]] ; then
        echoerr "problem at DWI_A_eddy. exiting."
        exit 1
    fi  
fi

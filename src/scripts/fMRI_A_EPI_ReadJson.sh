#!/bin/bash
#
###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

###############################################################################
msg2file "# =================================="
msg2file "# 0. Reading Scan Parameters"
msg2file "# =================================="

json_loc="${EPIfile::-6}json"

if [ -e "${json_loc}" ]; then
    log "JSON: Using json file to extract header information."
    log --no-datetime "Derivative EPIpath: ${EPIrun_out}"

    ## if 0_param_dcm_hdr.sh exists, remove it
    if [ -e "${EPIrun_out}/0_param_dcm_hdr.sh" ]; then
        rm ${EPIrun_out}/0_param_dcm_hdr.sh
    fi 

    # create the file and make it executable
    touch ${EPIrun_out}/0_param_dcm_hdr.sh
    chmod +x ${EPIrun_out}/0_param_dcm_hdr.sh
    
    EPI_slice_fractimes=`cat ${json_loc} | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_slice_fractimes}`
    # echo "export EPI_slice_fractimes=${EPI_slice_fractimes}" >> ${EPIrun_out}/0_param_dcm_hdr.sh
    log --no-datetime "SliceTiming extracted from json is $EPI_slice_fractimes"
    TR=`cat ${json_loc} | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_TR}`
    log --no-datetime "RepetitionTime extracted from json is $TR"
    echo "export TR=${TR}" >> ${EPIrun_out}/0_param_dcm_hdr.sh
    TE=`cat ${json_loc} | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_TE}`
    log --no-datetime "EchoTime extracted from json is $TE"
    echo "export TE=${TE}" >> ${EPIrun_out}/0_param_dcm_hdr.sh
    EPI_FlipAngle=`cat ${json_loc} | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_FlipAngle}`
    log --no-datetime "FlipAngle extracted from json is $EPI_FlipAngle"
    echo "export EPI_FlipAngle=${EPI_FlipAngle}" >> ${EPIrun_out}/0_param_dcm_hdr.sh
    EPI_EffectiveEchoSpacing=`cat ${json_loc} | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_EffectiveEchoSpacing}`
    log --no-datetime "EffectiveEchoSpacing extracted from json is $EPI_EffectiveEchoSpacing"    
    echo "export EPI_EffectiveEchoSpacing=${EPI_EffectiveEchoSpacing}" >> ${EPIrun_out}/0_param_dcm_hdr.sh                                                        
    EPI_BandwidthPerPixelPhaseEncode=`cat ${json_loc} | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_BandwidthPerPixelPhaseEncode}`
    log --no-datetime "BandwidthPerPixelPhaseEncode extracted from json is $EPI_BandwidthPerPixelPhaseEncode"
    echo "export EPI_BandwidthPerPixelPhaseEncode=${EPI_BandwidthPerPixelPhaseEncode}" >> ${EPIrun_out}/0_param_dcm_hdr.sh

    # find TotalReadoutTime
    EPI_TotalReadoutTime=`cat ${json_loc} | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_TotalReadoutTime}`
    log --no-datetime "TotalReadoutTime extracted from json is $scanner_param_TotalReadoutTime"
    echo "export EPI_TotalReadoutTime=${EPI_TotalReadoutTime}" >> ${EPIrun_out}/0_param_dcm_hdr.sh

    # Relying on BIDS standard json, so this can be retired since we wont necessarity have access to dicom source
    # cmd="${EXEDIR}/src/scripts/get_readout.sh ${json_loc} ${EPIpath}/DICOMS func" 
    # log $cmd
    # EPI_SEreadOutTime=`$cmd`
    # log --no-datetime "EPI_SEreadOutTime = ${EPI_SEreadOutTime}"
    # echo "export EPI_SEreadOutTime=${EPI_SEreadOutTime}" >> ${EPIrun_out}/0_param_dcm_hdr.sh

    # get the SliceTiming values in an array
    declare -a starr; 
    for val in $EPI_slice_fractimes; do 
        starr+=($val); 
    done                    
    starr=("${starr[@]:1:$((${#starr[@]}-2))}")    # remove [ and ] at beginning and end of array                                   
    starr=( "${starr[@]/,}" )  # remove commas at end of lines,
    
    # ########### just to test slice extraction ##################
    # starr=("${starr[@]:1:$((${#starr[@]}-36))}") ##DELETE THIS LINE                    
    # ###########################################################

    n_slice=${#starr[@]}
    log --no-datetime "SliceTiming extracted from header; number of slices: ${n_slice}"
    echo "export n_slice=${n_slice}" >> ${EPIrun_out}/0_param_dcm_hdr.sh

    printf "%f\n" "${starr[@]}" > "${EPIrun_out}/temp.txt"                    
                        
    while IFS= read -r num; do
        norm=$(bc <<< "scale=8 ; $num / $TR")
        norm2=$(bc <<< "scale=8 ; $norm - 0.5")
        echo $norm2
    done < "${EPIrun_out}/temp.txt"  > "${EPIrun_out}/slicetimes_frac.txt"

    rm -vf "${EPIrun_out}/temp.txt"

    ## Extract Slicing time
    cmd="${EXEDIR}/src/scripts/extract_slice_time.sh ${EPIrun_out} ${starr[@]}" 
    echo $cmd
    eval $cmd
    # exitcode=$?
    log "Config params are saved in ${EPIrun_out}/0_param_dcm_hdr.sh"
fi

### Andrea Note: The source files will not be available for most of our data and we cannot rely on them 
#                being placed at a hard-coded path. Therefore, I'd propose that we discontinue support
#                for dicom reading, and remove the portion of code that is commented below. 
#                Instead, we could prompt the user to manually create their own 0_param_dc_hdr.sh file.




# else
# # If json file does not exist
#     # Check if source flag is turned on
#     if ${flags_EPI_UseSource}; then
#         log "No JSON found. Checking if source directory exists per flags_EPI_UseSource=true."
#     else
#         log "No JSON found. Check that the file exists and is names in BIDS standard. Exiting."
#         break
#     fi

#     EPIpath_source="${path2proj}/source/${SUBJ}/${configs_session}/func"
#     if [ ! -d "$EPIpath_source" ]; then
#         log "No source func directory found. Dicoms need to be in source func directry; OTHERWISE NOT SUPPORTED"
#         break
#     else
# #THIS WILL NEED TO BE REFINED OR REMOVED IF WERE DROPING SUPPORT FOR SOURCE DATA

#         # Identify DICOMs
#         declare -a dicom_files
#         while IFS= read -r -d $'\0' dicomfile; do 
#             dicom_files+=( "$dicomfile" )
#             # dcmFiles was the extension dcm; I deleted it
#         done < $(find ${EPIpath_source} -iname "*.${configs_dcmFiles}" -print0 | sort -z)

#         if [ ${#dicom_files[@]} -eq 0 ]; then 
#             echo "No dicom (.${configs_dcmFiles}) images found."
#             echo "Please specify the correct file extension of dicom files by setting the configs_dcmFiles flag in the config file"
#             echo "Skipping further analysis"
#             exit 1
#         else
#             echo "There are ${#dicom_files[@]} dicom files in this EPI-series "
#         fi

#         # Extract Repetition time (TR)
#         # Dicom header information --> Flag 0018,0080 "Repetition Time"
#         cmd="dicom_hinfo -tag 0018,0080 ${dicom_files[0]}"                    
#         log $cmd 
#         out=`$cmd`                
#         TR=( $out )  # make it an array
#         TR=$(bc <<< "scale=2; ${TR[1]} / 1000")
#         log "-HEADER extracted TR: ${TR}"
#         echo "export TR=${TR}" >> ${EPIrun_out}/0_param_dcm_hdr.sh

#     #-------------------------------------------------------------------------%
#         # Slice Time Acquisition                    
#         dcm_file=${dicom_files[0]}
#         cmd="dicom_hinfo -no_name -tag 0019,100a ${dcm_file}"
#         log $cmd
#         n_slice=`$cmd`
#         log "-HEADER extracted number of slices: $n_slice"
#         echo "export n_slice=${n_slice}" >> ${EPIrun_out}/0_param_dcm_hdr.sh

#         id1=6
#         id2=$(bc <<< "${id1} + ${n_slice}")
#         log "id2 is $id2"

#         cmd="dicom_hdr -slice_times ${dcm_file}"  
#         log $cmd
#         out=`$cmd` 
#         echo $out
#         st=`echo $out | awk -F':' '{ print $2}'`
#         echo $st
#         starr=( $st )    

#         echo ${#starr[@]}

#         printf "%f\n" "${starr[@]}" > "${EPIrun_out}/temp.txt"                    
                            
#         while IFS= read -r num; do
#             val=$(bc <<< "scale=8 ; $num / 1000")
#             val2=$(bc <<< "scale=8 ; $val / $TR")
#             echo $val2
#         done < "${EPIrun_out}/temp.txt"  > "${EPIrun_out}/slicetimes_frac.txt"

#         rm -vf "${EPIrun_out}/temp.txt"

#         cmd="${EXEDIR}/src/scripts/extract_slice_time.sh $EPIrun_out ${starr[@]}" # -d ${PWD}/inputdata/dwi.nii.gz \
#         echo $cmd
#         eval $cmd

#         dcm_file=${dicom_files[0]}
#         cmd="dicom_hinfo -tag 0018,0081 ${dcm_file}"
#         log $cmd
#         out=`$cmd`
#         TE=`echo $out | awk -F' ' '{ print $2}'`
#         echo "HEADER extracted TE is: ${TE}" 
#         echo "export TE=${TE}" >> ${EPIrun_out}/0_param_dcm_hdr.sh

#         ## GRAPPA acceleration factor could be used in conjunction with BWPPE   
#         cmd="dicom_hinfo -tag 0051,1011 ${dcm_file}"
#         log $cmd
#         out=`$cmd`
#         GRAPPAacc=`echo $out | awk -F' ' '{ print $2}'`
#         echo "HEADER extracted Acceleration factor is: ${GRAPPAacc}" 
#         echo "export GRAPPAacc=${GRAPPAacc}" >> ${EPIrun_out}/0_param_dcm_hdr.sh


#         cmd="mrinfo -quiet -property TotalReadoutTime ${dcm_file}"
#         log $cmd
#         out=`$cmd`
#         TotalReadoutTime=`echo $out | awk -F' ' '{ print $1}'`
#         echo "HEADER extracted TotalReadoutTime is: ${TotalReadoutTime}" 
#         echo "export TotalReadoutTime=${TotalReadoutTime}" >> ${EPIrun_out}/0_param_dcm_hdr.sh


#         cmd="dicom_hinfo -tag 0051,100b ${dcm_file}"
#         log $cmd
#         out=`$cmd`
#         MATSIZPHASE=`echo $out | awk '{ print $2}' | sed 's/*.*//'` 
#         echo "HEADER extracted MATSIZPHASE is: ${MATSIZPHASE}" 
#         echo "export MATSIZPHASE=${MATSIZPHASE}" >> ${EPIrun_out}/0_param_dcm_hdr.sh

#         if [ "${MATSIZPHASE}" -ge "2" ]; then
#             MSP=$(bc <<< "scale=4 ; $MATSIZPHASE - 1") 
#             EPI_EffectiveEchoSpacing=$(bc <<< "scale=4 ; $TotalReadoutTime / $MSP")
#             echo "CALCULATED EffectiveEchoSpacing is: ${EPI_EffectiveEchoSpacing}" 
#             echo "export EPI_EffectiveEchoSpacing=${EPI_EffectiveEchoSpacing}" >> ${EPIrun_out}/0_param_dcm_hdr.sh
#         else
#             log "WARNING EffectiveEchoSpacing could not be calculated! ${MATSIZPHASE} < 2"
#             exit 1
#         fi

#     fi

#     #-------------------------------------------------------------------------%
#     # Config params are all saved in ${EPIrun_out}/0_param_dcm_hdr.sh     
#     log "Config params are saved in ${EPIrun_out}/0_param_dcm_hdr.sh"      

#     # ##esp
# fi
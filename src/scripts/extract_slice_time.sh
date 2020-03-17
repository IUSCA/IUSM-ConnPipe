#!/bin/bash
#
#

###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

EPIpath=$1
shift;
starr=("$@")
echo "EPIpath is $EPIpath"
echo "TimeSlices are ${starr[@]}"


# get unique values and sort them
slice_fractimes_uniq=($(echo "${starr[@]}" | tr ' ' '\n' | sort -u -g | tr '\n' ' ')) 
n_unique=${#slice_fractimes_uniq[@]}

if [ ${#starr[@]} -eq ${n_unique} ]; then
    echo ${starr[@]} 
    echo ${slice_fractimes_uniq[@]}
    echo "Slices were acquired at different times"
    ## checking if slices are sequential 
    diff1=0 
    diff2=0
    for ((j=0; j<${n_unique}; j++)); do 
        diff1=$(bc <<< "scale=3; $diff1 + ${starr[$j]} != ${slice_fractimes_uniq[$j]}")
        #echo "diff1 is $diff1"
        rev=$(bc <<< "$n_unique - 1 - $j")
        diff2=$(bc <<< "scale=3; $diff2 + ${starr[$j]} != ${slice_fractimes_uniq[$rev]}")
        #echo "diff2 is $diff2"
    done 
    if [ "${diff1}" -eq "0" ]; then   # Sequential; increasing from bottom to top (default)
        echo "Time Slices are Sequential; increasing from bottom to top (default)"
        slice_ord=1
        echo "export slice_ord=${slice_ord}" >> ${EPIpath}/0_param_dcm_hdr.sh
        slice_rev=0
        echo "export slice_rev=${slice_rev}" >> ${EPIpath}/0_param_dcm_hdr.sh
    elif [ "${diff2}" -eq "0" ]; then  # Sequential; increasing from top to bottom (--down)
        echo "Time Slices are Sequential; increasing from top to bottom (--down)"
        slice_ord=1
        echo "export slice_ord=${slice_ord}" >> ${EPIpath}/0_param_dcm_hdr.sh
        slice_rev=1
        echo "export slice_rev=${slice_rev}" >> ${EPIpath}/0_param_dcm_hdr.sh     
    else ## Not sequential; check if Interleaved
        declare -a odd
        declare -a even
        for ((j=0; j<${n_unique}; j+=2)); do 
            #echo "j -- $j"
            odd+=( ${starr[$j]} ); 
            ee=$(bc <<< "$j + 1")
            #echo "ee -- $ee"
            even+=( ${starr[$ee]} );
        done 
        echo ${odd[@]}
        echo ${even[@]}  
        oddsort=($(echo "${odd[@]}" | tr ' ' '\n' | sort -g | tr '\n' ' '))                          
        evensort=($(echo "${even[@]}" | tr ' ' '\n' | sort -g | tr '\n' ' '))    
        echo ${oddsort[@]} 
        echo ${evensort[@]}   
        if [[ $( echo "${oddsort[-1]} < ${evensort[0]}" | bc ) -eq "1" ]]; then
            slice_ord=0
            echo "export slice_ord=${slice_ord}" >> ${EPIpath}/0_param_dcm_hdr.sh
            # check if they are sorted 
            diff1=0 
            diff2=0
            for ((j=0; j<${#oddsort[@]}; j++)); do 
                diff1=$(bc <<< "scale=3; $diff1 + ${odd[$j]} != ${oddsort[$j]}")
                rev=$(bc <<< "${#oddsort[@]} - 1 - $j")
                diff2=$(bc <<< "scale=3; $diff2 + ${odd[$j]} != ${oddsort[$rev]}")
            done 
            if [ "${diff1}" -eq "0" ]; then   # increasing from bottom to top (default)
                echo "Time Slices are Interleaved; increasing from bottom to top "
                slice_rev=0
                echo "export slice_rev=${slice_rev}" >> ${EPIpath}/0_param_dcm_hdr.sh
            elif [ "${diff2}" -eq "0" ]; then  # increasing from top to bottom (--down)
                echo "Time Slices are Interleaved; increasing from top to bottom"
                slice_rev=1
                echo "export slice_rev=${slice_rev}" >> ${EPIpath}/0_param_dcm_hdr.sh 
            fi 
        elif [[ $( echo "${evensort[-1]} < ${oddsort[0]}" | bc ) -eq "1" ]]; then
            slice_ord=0
            echo "export slice_ord=${slice_ord}" >> ${EPIpath}/0_param_dcm_hdr.sh
            # check if they are sorted 
            diff1=0 
            diff2=0
            for ((j=0; j<${#evensort[@]}; j++)); do 
                diff1=$(bc <<< "scale=3; $diff1 + ${even[$j]} != ${evensort[$j]}")
                rev=$(bc <<< "${#oddsort[@]} - 1 - $j")
                diff2=$(bc <<< "scale=3; $diff2 + ${even[$j]} != ${evensort[$rev]}")
            done 
            if [ "${diff1}" -eq "0" ]; then   # increasing from bottom to top (default)
                echo "Time Slices are Interleaved; increasing from bottom to top "
                slice_rev=0
                echo "export slice_rev=${slice_rev}" >> ${EPIpath}/0_param_dcm_hdr.sh
            elif [ "${diff2}" -eq "0" ]; then  # increasing from top to bottom (--down)
                echo "Time Slices are Interleaved; increasing from top to bottom"
                slice_rev=1
                echo "export slice_rev=${slice_rev}" >> ${EPIpath}/0_param_dcm_hdr.sh 
            fi 
        else
            echo "Slice time information is not consistent with interleaved acquisition"
        fi                                                                                               
    fi 
else
    echo "Multiband (multiple slices acquired at a same time)"
    slice_ord=2
    echo "export slice_ord=${slice_ord}" >> ${EPIpath}/0_param_dcm_hdr.sh
fi 

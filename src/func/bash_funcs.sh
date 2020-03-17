<<'COMMENT'
josh faskowitz
Indiana University
Computational Cognitive Neurosciene Lab
Copyright (c) 2018 Josh Faskowitz
See LICENSE file for license
COMMENT

# colors

export RED_='\033[0;31m'
export GREEN_='\033[0;32m'
export YELLOW_='\033[0;33m'
export CYAN_='\033[0;36m'
export NC_='\033[0m' # No Color

################################################################################
## reads files list
check_required() {

    #read in list (could be list of 1
    local input_list=("$@")
    echo "input_list: ${input_list[@]}"

    for i in ${input_list[@]}
    do
        if [[ ! -e ${!i} ]]
        then
            echoerr "${i} does not exist"
            echoerr "problem with ${!i}"
            #and touch a file for convenience 
            touch "problem.yo"
            log "${i} for $subj does not exist: ${!i}" >> problem.yo
            # return an error
            return 1
        fi
    done

    # if we get here, return no error
    return 0 
}

check_inputs() {

    #read in list (could be list of 1
    local input_list=("$@")
    echo "input_list: ${input_list[@]}"

    for i in ${input_list[@]}
    do
        if [[ ! -e ${!i} ]]
        then
            log "${i} var does not exist: ${!i}" 
            # return an error
            return 1
        fi
    done

    # if we get here, return no error
    echo; echo "ALL INPUTS EXIST" ; echo
    return 0 
}

checkisfile() {

    local inFile=$1
    if [[ ! -f ${inFile} ]] ; then
        echoerr "file does not exist: $inFile"
        exit 1
    fi
}

################################################################################
## log message
log() {

    local msg=($(echo "$@"))
    local dateTime=`date`
    echo -e ${CYAN_}
    echo "# "$dateTime "-" ${msg[0]} "--->"
    echo -e ${NC_}     
    echo "${msg[@]}"
    echo -e ${NC_}

	echo "### $dateTime -" >> ${EXEDIR}/pipeline.log
    echo "${msg[@]}" >> ${EXEDIR}/pipeline.log
}

# https://stackoverflow.com/questions/2990414/echo-that-outputs-to-stderr
echoerr() {
    cat <<< "$(echo -e ${RED_}ERROR: $@ ${NC_})" 1>&2; 
}

lsrm() {
    file=($(echo "$@"))
    for ff in "${file[@]}" ; do
        echo -e "${YELLOW_}REMOVING: $ff ${NC_}"
        ls ${ff} && rm ${ff}
    done
}


###############################################################################

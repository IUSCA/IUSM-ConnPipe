<<'COMMENT'
inspired by josh faskowitz, modified by AAK
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
    log "input_list: ${input_list[@]}"

    for i in ${input_list[@]}
    do
        if [[ ! -e ${!i} ]]
        then
            echoerr "${i} does not exist"
            echoerr "problem with ${!i}"
            log "${i} for ${SUBJ}_${SESS} does not exist: ${!i}" 
            # return an error
            return 1
        fi
    done

    # if we get here, return no error
    echo; log "ALL FILES EXIST" ; echo
    return 0 
}

check_inputs() {

    #read in list (could be list of 1
    local input_list=("$@")
    log "input_list: ${input_list[@]}"

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
    echo; log "ALL INPUTS EXIST" ; echo
    return 0 
}

checkisfile() {

    local inFile=$1
    if [[ ! -f ${inFile} ]] ; then
        echoerr "file does not exist: $inFile"
        exit 1
    fi
}

checkisdir() {

    local inDir=$1
    if [[ ! -d ${inDir} ]] ; then
        echoerr "Directory does not exist: $inDir"
        exit 1
    fi
}

################################################################################
## log message
log() {
    local suppressDateTime=false
    local dateTime=`date`
    
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --no-datetime)
                suppressDateTime=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    local msg=($(echo "$@"))

    if [ "$suppressDateTime" = false ]; then
        echo -e ${CYAN_}
        echo "# "$dateTime " --->"
        echo -e ${NC_}
    fi

    echo -e "${msg[@]}"
    echo -e ${NC_}

	# echo "### $dateTime -" >> ${EXEDIR}/pipeline.log
    # echo "${msg[@]}" >> ${EXEDIR}/pipeline.log
    if [ "$suppressDateTime" = false ]; then
        echo "### $dateTime --->" >> ${logfile_name}.log
    fi
    echo "${msg[@]}" >> ${logfile_name}.log
}

## QC messages
qc() {
    local suppressDateTime=false
    local dateTime=`date`
    
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --no-datetime)
                suppressDateTime=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    local msg=($(echo "$@"))
    
    if [ "$suppressDateTime" = false ]; then
        echo -e ${CYAN_}
        echo "# "$dateTime " --->"
        echo -e ${NC_}
    fi

    echo "${msg[@]}"
    echo -e ${NC_}

    if [ "$suppressDateTime" = false ]; then
        echo "### $dateTime -" >> ${QCfile_name}.log
    fi
    echo "${msg[@]}" >> ${QCfile_name}.log
}

# print to log file only withouth printing to screen
log2file() {

    local msg=($(echo "$@"))
    local dateTime=`date`

    echo "### $dateTime --->" >> ${logfile_name}.log
    echo "${msg[@]}" >> ${logfile_name}.log
}

# print to log file and screen without a time-stamp (mostly used to separate sections of code in file)
msg2file() {

    local msg=($(echo "$@"))
    echo "${msg[@]}"
    echo "${msg[@]}" >> ${logfile_name}.log
}

# https://stackoverflow.com/questions/2990414/echo-that-outputs-to-stderr
echoerr() {
    
    cat <<< "$(echo -e ${RED_}ERROR: $@ ${NC_})" 1>&2; 
    local msg=($(echo "$@"))
    local dateTime=`date`
    echo -e ${RED_}
    echo "### $dateTime -" >> ${logfile_name}.log
    echo "ERROR" >> ${logfile_name}.log
    echo "${msg[@]}" >> ${logfile_name}.log
    echo -e ${NC_}

}

###############################################################################

#!/bin/bash





# IU modules load
module unload python/2.7.16; module load python/3.6.8 
module load fsl/6.0.1; 
module load mricrogl
module load afni/18.3.03
module load ants
module load ica-aroma/0.4.4
module load mrtrix/3.0
# module load singularity

# FSL
# set FSL env vars for fsl_sub.IU or fsl_sub.orig
if [[ -z ${FSLDIR} ]] ; then
	echoerr "FSLDIR not set"
	exit 1
fi

################################################################################
############################  PATH TO DATA  ###################################

# USER INSTRUCTIONS- PLEASE SET THIS PATH TO POINT TO YOUR DATA DIRECTORY
#export path2data="/N/project/YoderLab/NANCfN/Datadir"
export path2data="/N/project/hasda/DataDir"

    ## USER: if running all subjects in the path2data directory, set this flag to true; 
    ## set to false if you'd like to process a subset of subjects 
    export runAll=false 

    ## USER -- if running a subset of subjects, a list of subject ID's can be read from 
    ## a text file located in path2data; user can name the file here:
    export subj2run="subj2run_AAK.txt"



################################################################################
############################ Dependencies ######################################

# where this package of scripts are
export EXEDIR=$(dirname "$(readlink -f "$0")")

source ${EXEDIR}/src/func/bash_funcs.sh
source ${EXEDIR}/config.sh


#################################################################################
#################################################################################


## main
main() {

log "START running Connectivity Pipeline on the following subjects:"

IFS=$'\r\n' GLOBIGNORE='*' command eval 'SUBJECTS=($(cat ${path2data}/${subj2run}))'
log "subjects: ${SUBJECTS[@]}"

echo "##################"

# ######################################################################################################
# #### START PROCESSING SUBJECTS ###############

for SUBJdir in "${SUBJECTS[@]}"; do

    start=`date +%s`

    export SUBJ=${SUBJdir}
    
    log "Subject ${SUBJ}"

    export T1path="${path2data}/${SUBJ}/${configs_T1}"
    export DWIpath="${path2data}/${SUBJ}/${configs_DWI}"

    # user may specify name of logfile written inside each subjects dir
    today=$(date +"%m_%d_%Y_%H_%M")
    export logfile_name="${path2data}/${SUBJ}/out_${today}"
    export QCfile_name="${path2data}/${SUBJ}/qc"
 

    log "# ############################ T1_PREPARE_A #####################################"

        if $T1_PREPARE_A; then

            cmd="${EXEDIR}/src/scripts/t1_prepare_A.sh" # -d ${PWD}/inputdata/dwi.nii.gz \
            echo $cmd
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] ; then
                echoerr "problem at T1_PREPARE_A. exiting."
                continue
            fi
        else 
            log "SKIP T1_PREPARE_A for subject $SUBJ"
        fi 

    ######################################################################################
    log "# ############################ T1_PREPARE_B #####################################"


        if $T1_PREPARE_B; then

            if [[ -d "$T1path" ]]; then 

                cmd="${EXEDIR}/src/scripts/t1_prepare_B.sh" # -np ${numParcs} -d ${PWD}/inputdata/dwi.nii.gz \
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at T1_PREPARE_B. exiting."
                    continue
                fi
                        
            else
                echo "T1 directory doesn't exist; skipping subject $SUBJ"
            fi
        else
            log "SKIP T1_PREPARE_B for subject $SUBJ"
        fi 

    ######################################################################################
    log "# ############################ fMRI_A ###########################################"


        if $fMRI_A; then

            if [[ -d "$T1path" ]]; then 

                cmd="${EXEDIR}/src/scripts/fMRI_A.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at fMRI_A. exiting."
                    continue
                fi
                        
            else
                echo "T1 directory doesn't exist; skipping subject $SUBJ"
            fi
        else
            log "SKIP fMRI_A for subject $SUBJ"
        fi 

    ######################################################################################
    log "# ############################ fMRI_B ##########################################"

    ## Generates all the figures. Can still be called from Matlab for now...?


    ######################################################################################
    log "# ############################ DWI_A ############################################"


        if $DWI_A; then

            if [[ -d "${DWIpath}" ]]; then 

                cmd="${EXEDIR}/src/scripts/DWI_A.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at DWI_A. exiting."
                    continue
                fi
                        
            else
                echo "DWI directory doesn't exist; skipping subject $SUBJ"
            fi
        else
            log "SKIP DWI_A for subject $SUBJ"
        fi 

    ######################################################################################
    log "# ############################ DWI_B ############################################"


        if $DWI_B; then

            if [[ -d "${DWIpath}" ]]; then 

                cmd="${EXEDIR}/src/scripts/DWI_B.sh"
                echo $cmd
                eval $cmd
                exitcode=$?

                if [[ ${exitcode} -ne 0 ]] ; then
                    echoerr "problem at DWI_B. exiting."
                    continue
                fi
                        
            else
                echo "DWI directory doesn't exist; skipping subject $SUBJ"
            fi
        else
            log "SKIP DWI_B for subject $SUBJ"
        fi 

    # ################################################################################
    # ################################################################################

        ## time it
        end=`date +%s`
        runtime=$((end-start))
        log "SUBJECT $SUBJ runtime: $runtime"

    echo "#################################################################################"
    echo "#################################################################################"
    
done    

} # main

# ################################################################################
# ################################################################################
# ## run it

main "$@"


    # # get the whole call
    # cmdLineCall=$(echo "$0 $@")

    # # read in args
    # while (( $# > 1 )) ; do
    #     case "$1" in
    # 		-d | --data) shift
    # 			SUBJdir="${1}" 
    # 			shift
    # 			;;
    # 		-p | --parc) shift
    # 			PARCdir="${1}" 
    # 			shift
    # 			;;    
    # 		-o | --out) shift
    # 			OUTbasedir="${1}"
    # 			shift
    # 			;;
    #         -*)
    #             echo "ERROR: Unknown option '$1'"
    #             exit 1
    #             break
    #             ;;
    #         *)
    #             break
    #             ;;
    #      esac
    # done

    # shift "$((OPTIND-1))" # Shift off the options and optional

# ################################################################################
# ################################################################################
# ## check the arguments

    # # basic files needed
    # if [[ -d ${PARCdir} || -d ${SUBJdir} || -d ${OUTbasedir} ]] ; then
    # 	echoerr "missing required directories"
    # 	exit 1
    # fi

    # # get full path for out directroy
    # OUTbasedir=$(readlink -f ${OUTbasedir})

    # # cd into basedir
    # mkdir -vp ${OUTbasedir} || \
    # 	{ echoerr "could not make output dir. exitng" ; exit 1 ; }

    # echo ${cmdLineCall} > ${OUTbasedir}/cmdlinecall.txt

# ################################################################################
# ################################################################################
# ## run it

######################################################################################

    
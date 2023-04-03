#!/bin/bash
#
#
#
###############################################################################
#
# ---------------------------- GET_READOUT ---------------------------------
# Obtain readout time from dicom data for distortion correction in FSL EDDY.
#
#                   Effective Echo Spacing (s) = 
#        1 / (BandwidthPerPixelPhaseEncode (Hz) * MatrixSizePhase)
#
#   BandwidthPerPixelPhaseEncode -> Siemens dicom tag (0019, 1028)
#   MatrixSizePhase -> size of image in phase encode direction; usually the
# first number in the field (0051, 100b), AcquisitionMatrixText

#               Total Readout Time (FSL definition)
# Time from the center of the first echo to the center of the last
# =(actual number of phase encoding lines - 1)* effective echo spacing
#
# Actual number of phase encoding lines = 
#                       Image matrix in phase direction / GRAPPA factor

# Original Matlab code - Evgeny Chumin, Indiana University School of Medicine, 2018
#                        John West, Indiana University School of Medicine, 2018
##
###############################################################################

# shopt -s nullglob # No-match globbing expands to null

# source ${EXEDIR}/src/func/bash_funcs.sh

###############################################################################

function get_private_tags() {
SEreadOutTime=$(python - "$1"<<END
import pydicom
#import os
import sys
path2dicom=str(sys.argv[1])
#path2dicom=str(os.environ['PYTHON_ARG'])
# print(path2dicom)
dicomHeader=pydicom.read_file(path2dicom)
matrix=dicomHeader[0x0051100b].value
dim1=matrix.split('*')
dim1=int(dim1[1])
# accelerator factor
try: 
    AcqStr=dicomHeader[0x00511011].value
    Pstring=AcqStr.split('p')
    AccF=int(Pstring[0])
except:
    AccF=1
    
# bandwidth per pixel phase encoding (hz)
bppe=int(dicomHeader[0x00191028].value)
# Effective Echo Spacing (s)
ees=1/(bppe*dim1)
#actual number of phase encoding lines
anofel=dim1/AccF
# Total Readout Time (s)
RT=(anofel-1)*ees
print(RT)
#sys.stdout.write(str(RT))
END
)
}


###############################################################################

source ${EXEDIR}/src/func/bash_funcs.sh

## Set paths and check for dicom direcotry
jsonfile=$1 dicomPath=$2 modality=$3

if [[ -f "${jsonfile}" ]]; then 

    # find TotalReadoutTime
    SEreadOutTime=`cat ${jsonfile} | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_TotalReadoutTime}`
    
    if [[ ${modality} == "DWI" ]]; then
        AccF=`cat ${jsonfile} | ${EXEDIR}/src/func/jq-linux64 '.ParallelReductionFactorInPlane'`
        log2file "ParallelReductionFactorInPlane (AccF) extracted from ${jsonfile} is - ${AccF}"
        if [ -z "${AccF}" ] || [[ "${AccF}" -eq "null" ]]; then
            log2file "AccF is undefined"
        else 
            SEreadOutTime=$(bc <<< "scale=8 ; ${SEreadOutTime} / ${AccF}")
        fi
    fi

    log2file "first attemtp: SEredOutTime is ${SEreadOutTime}"

    # if not found in json file try to compute from other keys 
    if [ -z "${SEreadOutTime}" ] || [[ "${SEreadOutTime}" -eq "null" ]]; then 

        log2file "WARNING key ${scanner_param_TotalReadoutTime} was not found in ${jsonfile}"
        log2file "Computing ${scanner_param_TotalReadoutTime} from other variables... "

        dim1=`cat ${jsonfile} | ${EXEDIR}/src/func/jq-linux64 .${scammer_param_AcquisitionMatrix}`
        dim1=`echo $dim1 | awk '{ print $2}' | sed 's/*.*//'`
        dim1=${dim1%,*}

        log2file "Acquisition Matrix (dim1) is - ${dim1}"
        
        ees=`cat ${jsonfile} | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_EffectiveEchoSpacing}`
        log2file "EffectiveEchoSpacing (ees) is - ${ees}"
        if [[ "${modality}" == "DWI" ]]; then
            AccF=`cat ${jsonfile} | ${EXEDIR}/src/func/jq-linux64 '.ParallelReductionFactorInPlane'`
            log2file "ParallelReductionFactorInPlane (AccF) is - ${AccF}"
        elif [[ "${modality}" == "EPI" ]]; then
            AccF=1
            log2file "AccF is - ${AccF}"
        fi 

        if [ -z "${AccF}" ] || [[ "${AccF}" -eq "null" ]]; then
            log2file "AccF is undefined"
        else 
            
            anofel=$(bc <<< "scale=8 ; ${dim1} / ${AccF}")
            temp=$(bc <<< "scale=8 ; ${anofel} - 1")
            SEreadOutTime=$(bc <<< "scale=8 ; ${temp} * ${ees}")
        fi
    fi
fi 

log2file "second attemtp: SEredOutTime is ${SEreadOutTime}"

if [ -z ${SEreadOutTime} ]; then 

    log2file "SEreadOutTime could not be calculated from ${jsonfile}; extracting from DICOM files"
    # extract the variable from dicom files 
    # Identify DICOMs
    declare -a dicom_files
    while IFS= read -r -d $'\0' dicomfile; do 
        dicom_files+=( "$dicomfile" )
    done < <(find ${dicomPath} -iname "*.${configs_dcmFiles}" -print0 | sort -z)

    if [ ${#dicom_files[@]} -eq 0 ]; then 
        log2file "No dicom (.${configs_dcmFiles}) images found at ${dicomPath}."
        log2file "Please specify the correct file extension of dicom files by setting the configs_dcmFiles flag in the config file"
        log2file "Skipping further analysis"
        exit 1
    else
        log2file "There are ${#dicom_files[@]} dicom files in ${dicomPath} "

        ## create a temp dir to extract header inf
        temp_dir="${dicomPath}/Dir2delete"
        cmd="mkdir ${temp_dir}"
        log2file $cmd
        eval $cmd 

        cmd="cp ${dicom_files[0]} ${temp_dir}"
        log2file $cmd
        eval $cmd

        tempfile="temp_epi"

        # import dicoms
        fileLog="${temp_dir}/temp_dcm2niix.log"
        cmd="dcm2niix -f ${tempfile} -o ${temp_dir} -v y -x y ${temp_dir} > ${fileLog}"
        log2file $cmd
        eval $cmd

        if [[ ! -e "${temp_dir}/${tempfile}.json" ]]; then
            log2file "${temp_dir}/${tempfile}.json file not created. Exiting... "
            exit 1
        else
            SEreadOutTime=`cat ${temp_dir}/${tempfile}.json | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_TotalReadoutTime}`
            log2file "SEreadOutTime extracted from ${temp_dir}/${tempfile}.json file is ${SEreadOutTime}"
            
            if [[ ${modality} == "DWI" ]]; then
                AccF=`cat ${temp_dir}/${tempfile}.json | ${EXEDIR}/src/func/jq-linux64 '.ParallelReductionFactorInPlane'`
                log2file "ParallelReductionFactorInPlane (AccF) extracted from ${temp_dir}/${tempfile}.json is - ${AccF}"
                if [ -z "${AccF}" ] || [[ "${AccF}" -eq "null" ]]; then
                    log2file "AccF is undefined"
                else 
                    SEreadOutTime=$(bc <<< "scale=8 ; ${SEreadOutTime} / ${AccF}")
                fi
            fi
            rm -rf ${temp_dir}
        fi
    fi
fi

log2file "third attemtp: SEredOutTime is ${SEreadOutTime}"

# check again to see if read out time has been extracted
if [ -z ${SEreadOutTime} ]; then

    log2file "SEreadOutTime could not be calculated from ${temp_dir}/${tempfile}.json; extracting from DICOM header file"

    # Identify DICOMs
    declare -a dicom_files
    while IFS= read -r -d $'\0' dicomfile; do 
        dicom_files+=( "$dicomfile" )
    done < $(find ${dicomPath} -iname "*.${configs_dcmFiles}" -print0 | sort -z)

    if [ ${#dicom_files[@]} -eq 0 ]; then 
        log2file "No dicom (.${configs_dcmFiles}) images found."
        log2file "Please specify the correct file extension of dicom files by setting the configs_dcmFiles flag in the config file"
        log2file "Skipping further analysis"
        exit 1
    else
        #echo "There are ${#dicom_files[@]} dicom files in this EPI-series "

        dcm_file=${dicom_files[0]}

        log2file "Calling Python script to extract tags from dicom header"
        get_private_tags ${dcm_file}
        
        log2file "SEreadOutTime extracted from dicom headers is $SEreadOutTime"
    fi
fi 
  
echo "${SEreadOutTime}"
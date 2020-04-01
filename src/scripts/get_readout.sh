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
RedoutTime=$(python - "$1"<<END
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
    AcqStr=dicomHeader[0x0051100b].value
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

## Set paths and check for dicom direcotry
path=$1
dicomPath="${path}/DICOMS"
#echo "get_readout -- path is -- ${dicomPath}"

if [ "$(ls -A ${dicomPath})" ]; then
        # Identify DICOMs
    declare -a dicom_files
    while IFS= read -r -d $'\0' dicomfile; do 
        dicom_files+=( "$dicomfile" )
    done < <(find ${dicomPath} -iname "*.${configs_dcmFiles}" -print0 | sort -z)

    if [ ${#dicom_files[@]} -eq 0 ]; then 
        echo "No dicom (.IMA or .dcm) images found. Skipping further analysis"
        exit 1
    else
        #echo "There are ${#dicom_files[@]} dicom files in this EPI-series "

        dcm_file=${dicom_files[0]}

        #echo "Calling Python script 
        get_private_tags ${dicom_files[0]}
        echo "${RedoutTime}"


        # cmd="python ${EXEDIR}/src/scripts/get_private_tags.py ${dicom_files[0]}" 
        # log $cmd
        # out=`$cmd`
        # RT=`echo $out | awk -F' ' '{ print $2}'`
        # echo "${RT}" 
        
    fi

else
    echo "WARNING No files found in dicom direcoty. Import terminated. "
    exit 1
fi



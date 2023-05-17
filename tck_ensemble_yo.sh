#!/bin/bash


# if you had to sbatch it....
# SBATCH -J trkpar
# SBATCH --mail-user=somebody@iu.edu 
# SBATCH --mail-type=END,FAIL,ARRAY_TASKS
# SBATCH -p general
# SBATCH --nodes=1
# SBATCH --ntasks-per-node=4
# SBATCH --time=19:45:00
# SBATCH --mem=22G

<<'COMMENT'
josh faskowitz
Indiana University
Computational Cognitive Neuroscience Lab
Copyright (c) 2022 Josh Faskowitz

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
COMMENT

################################################################################
# setup your computing enviorment yo

# define the number of threads you want mrtrix to use
export MRTRIX_NTHREADS=4

# load the tools how you need to yooooo
# module load freesurfer
# module load ants
# module load mrtrix 

################################################################################
# nice little noclob function yo

noclob_run()
{
    expected_out=$1
    cmd=$2

    if [[ "$#" -ne 2 ]] ; then
        echo "need two arguements to run"
        exit 1
    fi

    if [[ -f $expected_out ]] ; then 
        echo "found $1, not running" 
    else
        echo "running: $cmd"
        eval ${cmd}
    fi
}

help_text()
{
    echo "This is a tckgen script.. see script insides to run"
    echo "need: -o -w -f -a -p"  
}

################################################################################
# parse some args!!!

# what we need: outputdir, workingdir, fodimg, act5tt

if [[ $# -eq 0 ]] ; then
    echo "no inputs"
    help_text
    exit 0 
fi

while (( $# > 0 ))
do
    case "$1" in
        -o | --outdir )
          OUTDIR="$2"
          shift 2
          ;;
        -w | --workdir )
          WORKDIR="$2"
          shift 2
          ;;
        -f | --fod )
          IFOD="$2"
          shift 2
          ;;
        -a | --act )
          IACT="$2"
          shift 2
          ;;
        -p | --parc )
          IPARC="$2"
          shift 2
          ;;
        -h | --help)
          help_text
          exit 0
          ;;
        -*)
          echo "ERROR, unknown option: $1"
          exit 1
          ;;
        *)
          echo "nothing read"
          exit 1
          ;;
    esac
done

shift "$((OPTIND-1))" # Shift off the options for safety??

################################################################################

[[ -e ${IFOD} ]] || \
    { echo "ERROR: ifod does not exist: $IFOD" ; exit 1 ; }  
[[ -e ${IACT} ]] || \
    { echo "ERROR: act5ttgen does not exist: $IACT" ; exit 1 ; }  
mkdir -p ${WORKDIR} || \
    { echo "ERROR: could not make WORKDIR: $WORKDIR" ; exit 1 ; }  
mkdir -p ${OUTDIR} || \
    { echo "ERROR: could not make OUTDIR: $OUTDIR" ; exit 1 ; }  

################################################################################

start=`date +%s`

# test out if ya want...
DEBUG="false" # set to "true" if you want to debug or retain all the files
parc_img=$IPARC
conn_opts="-assignment_radial_search 5 -symmetric -zero_diagonal"

if [[ $DEBUG = "true" ]] && [[ ! -e $parc_img ]] ; then
    echo "ERROR: input parc for debugging does not exist yo"
    exit 1
fi

# if we got to here..
echo "inputs read sucessfully"

################################################################################

# make wm seed
noclob_run ${WORKDIR}/wm.nii.gz \
     "mrconvert -coord 3 2  -axes 0,1,2 ${IACT} ${WORKDIR}/wm.nii.gz"

################################################################################

# could programatically make voxel size steps... 
# vox_sz=$(mrinfo dwi.mif -spacing | awk '{print $1}')
step_sizes=(0.625 1.25 1.875 2.5 )
max_angles=(30 45 60) # fine coverage if you ask me! 

################################################################################
################################################################################
# TCKGEN loop the ensembe 

# don't overwrite if combo already there
if [[ ! -e ${WORKDIR}/combo.tck ]] ; then 
    combo_list=""

    for (( sDx=0 ; sDx<${#step_sizes[@]} ; sDx++ )) ; do
        for (( mDx=0 ; mDx<${#max_angles[@]} ; mDx++ )) ; do

            l_step=${step_sizes[$sDx]}
            l_angle=${max_angles[$mDx]}

            echo "$sDx $mDx"
            echo "running step size: $l_step, angle size: $l_angle"

            outstr=$(echo "ss$l_step-ma$l_angle" | sed s,\\.,p,)

            trk_start=`date +%s`
            ## LONG
            noclob_run ${WORKDIR}/tracks_${outstr}.tck \
                "tckgen \
                    -algorithm iFOD2 \
                    -seeds 2M \
                    -angle $l_angle \
                    -step $l_step \
                    -minlength 10.0 \
                    -maxlength 220.0 \
                    -act ${IACT} \
                    -power 0.33 \
                    -backtrack -crop_at_gmwmi \
                    -max_attempts_per_seed 150 \
                    -seed_image ${WORKDIR}/wm.nii.gz \
                    -downsample 2 \
                    ${IFOD} ${WORKDIR}/tracks_${outstr}.tck"

            [[ ${DEBUG} = "true" ]] && noclob_run ${WORKDIR}/mat_${outstr}.csv \
                "tck2connectome \
                    ${WORKDIR}/tracks_${outstr}.tck \
                    ${parc_img} ${WORKDIR}/mat_${outstr}.csv \
                    ${conn_opts}"

            combo_list="$combo_list ${WORKDIR}/tracks_${outstr}.tck"

            trk_end=$(date +%s)
            echo "loop time: $(( trk_end - trk_start ))"

        done # angle
    done # step

    # combine all the tck yoooooooooo
    tckedit $combo_list ${WORKDIR}/combo.tck -force
    [[ ${DEBUG} = "true" ]] && noclob_run ${WORKDIR}/mat_combo.csv \
        "tck2connectome \
            ${WORKDIR}/combo.tck \
            ${parc_img} ${WORKDIR}/mat_combo.csv \
            ${conn_opts}"

    if [[ ${DEBUG} != "true" ]] && [[ -e ${WORKDIR}/combo.tck ]] ; then
        ls ${WORKDIR}/tracks*tck && rm ${WORKDIR}/tracks*tck
    fi

fi # if combo.tck does not exist

################################################################################
################################################################################
# SIFT 1

# LONG PROCESS
noclob_run ${WORKDIR}/tracks_sift1.tck \
    "tcksift \
        ${WORKDIR}/combo.tck \
        ${IFOD} ${WORKDIR}/tracks_sift1.tck \
        -act ${IACT} " 

if [[ ! -e ${WORKDIR}/tracks_sift1.tck ]] ; then
    echo "sift1 failure"
    exit 42
fi

if [[ ${DEBUG} != "true" ]] && [[ -e ${WORKDIR}/tracks_sift1.tck ]] ; then
    ls ${WORKDIR}/combo.tck && rm ${WORKDIR}/combo.tck
fi

################################################################################

end=$(date +%s)
runtime=$((end-start))
echo "runtime: $runtime"

# made it yo
exit 0


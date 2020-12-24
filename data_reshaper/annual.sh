#!/bin/bash -l
#
#SBATCH -n 64
#SBATCH -N 4
#SBATCH --ntasks-per-node=16
#SBATCH -t 1:00:00
#SBATCH -p dav
#SBATCH --account=P93300606
#SBATCH --mem 100G
#SBATCH -m block
#
module purge
conda deactivate || echo "conda not loaded"
#
# PARSE COMMAND LINE ARGUMENTS
if [ $# != 5 ]; then
  echo "ERROR: got $# arguments"
  echo "usage: $0 CASE ARCHIVE_ROOT START_YEAR END_YEAR COMPONENT"
  exit 1
fi
CASE=${1} ; export CASE
ARCHIVE_ROOT=${2}
START_YEAR=${3}
END_YEAR=${4}
COMPONENT=${5}
echo "Reshaping ${COMPONENT} output for years ${START_YEAR} through ${END_YEAR} for ${CASE}..."
#
cd /glade/p/cesm/postprocessing_dav/cesm-env2/bin
. activate
#
module load intel/17.0.1
module load ncarenv
module load ncarcompilers
module load impi
module load netcdf/4.6.1
module load nco/4.7.4
module load ncl/6.4.0
#
HIST=pop.h.nyear1 ; export HIST
case "$COMPONENT" in
  pop )
    HIST=pop.h.ecosys.nyear1 ;;
  * )
    echo "Unknown component ${COMPONENT}"
    exit 1 ;;
esac
export HIST

PATH=/glade/p/cesm/postprocessing_dav/cesm-env2/bin:/usr/local/bin:${PATH} ; export PATH
#
NCKS=`which ncks`  ; export NCKS
PROCHOST=`hostname`;export PROCHOST
#
BASEDIR=/glade/u/home/strandwg/CCP_Processing_Suite
LOCALDSK=${ARCHIVE_ROOT}/${CASE} ; export LOCALDSK
PROCBASE=/glade/scratch/$USER/reshaper/${CASE}     ; export PROCBASE
#
HTYP=`echo $HIST | cut -d'.' -f1` ; export HTYP
case "$HTYP" in
  cam2 | cam )
    COMP_NAME=atm ;;
  cism )
    COMP_NAME=glc ;;
  clm2 )
     COMP_NAME=lnd ;;
  pop  )
    COMP_NAME=ocn ;;
  rtm | mosart )
    COMP_NAME=rof ;;
  cice | csim )
    COMP_NAME=ice ;;
  * )
    echo "Unable to continue because "$HIST" not known."
    exit 1 ;;
esac
#
LOCAL_HIST=${LOCALDSK}/${COMP_NAME}/hist ; export LOCAL_HIST
LOCAL_PROC=${PROCBASE}/${HIST}/proc      ; export LOCAL_PROC
CACHEDIR=${LOCAL_PROC}/COMPLETED         ; export CACHEDIR
#
VERBOSITY=0 ; export VERBOSITY
PREFIX="${CACHEDIR}/${CASE}.${HIST}." ; export PREFIX
NCFORMAT=netcdf4c ; export NCFORMAT ; export NCFORMAT
#
if [ ! -d $LOCAL_PROC ] ; then
 mkdir -p $LOCAL_PROC
fi
if [ ! -d $CACHEDIR ] ; then
 mkdir -p $CACHEDIR
fi
#
cd $LOCAL_PROC
ln -s -f $BASEDIR/run_slice2series_dav Transpose_Data
#
rm -f ${CASE}.${HIST}.*nc
if [ ! -f ${LOCAL_PROC}/.DONE.${CASE}.${HIST}.${START_YEAR}_${END_YEAR} ] ; then
  HISTF=
  for YEAR in $(seq ${START_YEAR} ${END_YEAR}) ; do
    echo "YEAR: ${YEAR}"
    echo "LINKING FROM ${LOCAL_HIST}"
    ln -s -f ${LOCAL_HIST}/${CASE}.${HIST}.${YEAR}*nc .
    HISTF+="${CASE}.${HIST}.${YEAR}*nc "
  done
  NHISTF=`/bin/ls ${HISTF} | wc -l`
  OUTTIME="${START_YEAR}-${END_YEAR}"
  SUFFIX=".${OUTTIME}.nc" ; export SUFFIX
  echo -n "TS transpose_data start: " ; date
  ./Transpose_Data
  if [ $? -ne 0 ] ; then
    echo "Transpose_Data failed"
    exit 1
  fi
  echo -n "TS transpose_data end  : " ; date
  touch ${LOCAL_PROC}/.DONE.${CASE}.${HIST}.${START_YEAR}_${END_YEAR}
fi
#
echo -n "TS COMPLETE: " ; date
#
exit

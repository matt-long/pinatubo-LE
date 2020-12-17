#!/bin/bash
# Inputs:
#   * $CASE
#
# This script will loop through all valid ${stream} values and copy
# output from /glade/scratch/mlevy/reshaper/${CASE}/${stream}/proc/COMPLETED
# to /glade/campaign/univ/udeo0005/cesmLE_no_pinatubo/${component}/proc/tseries/${freq}/${var}

################

# Common error message for bad component / freq pair
bad_component_freq() {
  echo "ERROR: no ${freq} frequency for ${component} component"
  exit 1
}

################

# Determine stream name from component and freq
get_stream() {
  case ${component} in
    "ocn" )
      case ${freq} in
        "monthly" )
          stream="pop.h"
        ;;
        * )
          bad_component_freq
        ;;
      esac
      ;;
    * )
      echo "ERROR: unknown component ${component}"
      exit 1
    ;;
  esac
}

################

# Generate a file list to use with global transfer --batch
gen_file_list() {
  # Inputs:
  #   $1: component that generated data (atm, ice, lnd, ocn, rof)
  #   $2: frequency of output (hourly1, hourly6, daily, monthly, annual)
  # Output:
  #   globus_transfer_list.txt is formatted for globus transfer --batch

  component=$1
  freq=$2
  stream=
  get_stream

  SRC_ROOT=${GLADE_ROOT}/${MEMBER}/${stream}/proc/COMPLETED
  DEST_ROOT=${CAMPAIGN_ROOT}/${component}/proc/tseries/${freq}
  rm -f globus_transfer_list.txt
  for var in `ls ${DEST_ROOT}` ; do
    if [ -d ${DEST_ROOT}/${var} ]; then
      file=`cd ${SRC_ROOT} ; ls *.${var}.*.nc 2>/dev/null`
      if [ "${file}" ]; then
        echo "${file} $var/$file" >> globus_transfer_list.txt
      else
        echo "No file for ${var}"
      fi
    else
      echo "${DEST_ROOT}/${var} is a file, not directory"
    fi
  done
}

################

# Function to call globus transfer given label, source location,
# dest location, and possibly additional arguments
transfer() {
  # Inputs
  #   $1: label for transfer
  #   $2: additional opts (optional)
  label=${1//./_} # replace . with _ for label
  echo ${label}
  echo "Copying from ${SRC_ROOT} to ${DEST_ROOT}"
  globus transfer $OPTS $2 --label $label ${GLADE}:${SRC_ROOT} ${CAMPAIGN}:${DEST_ROOT} < globus_transfer_list.txt
  rm globus_transfer_list.txt
}

################

# Must have globus-cli installed and must be on casper
globus --version > /dev/null 2>&1 && GLOBUS_FOUND=TRUE

if [ ! "${GLOBUS_FOUND}" ]; then
  echo "Can not find globus-cli!"
  exit 1
fi

if [ "`hostname | cut -d '-' -f 1`" != "casper" ]
then
  echo "Can not run on `hostname`, need to run on Casper!"
  exit 1
fi

# Set up some global variables for globus / file detection
GLADE="d33b3614-6d04-11e5-ba46-22000b92c6ec"
CAMPAIGN="6b5ab960-7bbf-11e8-9450-0a6d4e044368"
OPTS="--sync-level checksum --preserve-mtime --verify-checksum --notify on --batch"
GLADE_ROOT=/glade/scratch/mlevy/reshaper
CAMPAIGN_ROOT=/glade/campaign/univ/udeo0005/cesmLE_no_pinatubo
MEMBER=b.e11.B20TRC5CNBDRD_no_pinatubo.f09_g16.001

# Activate globus
cmd="globus endpoint activate --web ${GLADE}"
echo "Activating globus..."
echo "\$ ${cmd}"
${cmd}
read -p "Log in to globus via the above URL then press enter to continue..."

if [ ! -d ${GLADE_ROOT}/${MEMBER} ]; then
  echo "ERROR: can not find ${MEMBER} in ${GLADE_ROOT}"
  exit 1
fi

gen_file_list ocn monthly
transfer ${stream}

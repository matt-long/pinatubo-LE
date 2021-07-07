#!/bin/bash

usage() {
  echo "usage:"
  echo "    $0 COMPONENT FREQ"
  echo ""
  echo "Lists all variables that are available in a time series file from COMPONENT"
  echo "that are output with a frequency of FREQ."
}

if [ "$1" == "-h" ]; then
  usage
  exit 0
fi
if [ $# != 2 ]; then
  usage
  exit 1
fi
ROOTDIR=/glade/campaign/cesm/collections/cesmLE/CESM-CAM5-BGC-LE
compset=B20TRC5CNBDRD
casename=b.e11.${compset}.f09_g16.001
component=$1
freq=$2
tseries_dir=${ROOTDIR}/${component}/proc/tseries/${freq}

# There are three reasons why tseries_dir might not exist, and we abort cleanly for all of them:
# (1) campaign is not available
if [ ! -d "${ROOTDIR}" ]; then
  echo "Can not find ${ROOTDIR}; note that cheyenne does not mount campaign!"
  exit 1
fi

# (2) Invalid component
if [ ! -d "${ROOTDIR}/${component}" ]; then
  echo "'${component}' is not a valid component, can not find ${ROOTDIR}/${component}"
  echo "Try one of these:"
  ls ${ROOTDIR}
  exit 1
fi

# (3) Invalid frequency
if [ ! -d "${tseries_dir}" ]; then
  echo "'${freq}' is not a valid frequency, can not find ${tseries_dir}"
  echo "Try one of these:"
  ls ${ROOTDIR}/${component}/proc/tseries/
  exit 1
fi

cd ${tseries_dir}
for varname in `ls`
do
  if [ "$component" == "ice" ]; then
    file=`ls -1 ${varname}/${casename}.* 2>&1 | head -n1`
  else
    file=`ls ${varname}/${casename}.* 2>&1`
  fi
  if [ -e "$file" ]; then
    #echo $file | cut -d '.' -f 8 | sort -u
    echo $varname
  fi
done

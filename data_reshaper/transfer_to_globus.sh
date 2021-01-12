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
get_streams() {
  case ${component} in
    "atm" )
      case ${freq} in
        "daily" )
          streams="cam.h1"
        ;;
        "hourly6" )
          streams="cam.h2"
        ;;
        "monthly" )
          streams="cam.h0"
        ;;
        * )
          bad_component_freq
        ;;
      esac
      ;;
    "ice" )
      case ${freq} in
        "daily" )
          streams="cice.h1"
        ;;
        "monthly" )
          streams="cice.h"
        ;;
        * )
          bad_component_freq
        ;;
      esac
      ;;
    "lnd" )
      case ${freq} in
        "daily" )
          streams="clm2.h1"
        ;;
        "monthly" )
          streams="clm2.h0"
        ;;
        * )
          bad_component_freq
        ;;
      esac
      ;;
    "ocn" )
      case ${freq} in
        "annual" )
          streams="pop.h.ecosys.nyear1"
        ;;
        "daily" )
          streams="pop.h.nday1 pop.h.ecosys.nday1"
        ;;
        "monthly" )
          streams="pop.h"
        ;;
        * )
          bad_component_freq
        ;;
      esac
      ;;
    "rof" )
      case ${freq} in
        "daily" )
          streams="rtm.h1"
        ;;
        "monthly" )
          streams="rtm.h0"
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
  #   globus_lists/globus_transfer_list_$LABEL.txt is formatted for globus transfer --batch

  component=$1
  freq=$2
  streams=
  get_streams

  rm -f globus_lists/globus_transfer_list_${component}_${freq}.txt
  SRC_ROOT=${GLADE_ROOT}/${MEMBER}
  DEST_ROOT=${CAMPAIGN_ROOT}/${component}/proc/tseries/${freq}
  for var in `ls ${DEST_ROOT}` ; do
    if [ ! -d ${DEST_ROOT}/${var} ] ; then
      echo "${DEST_ROOT}/${var} is a file, not directory"
      continue
    fi
    VAR_FOUND=FALSE
    for stream in ${streams} ; do
      if [ "${VAR_FOUND}" == "TRUE" ] ; then
        continue
      fi
      file=`cd ${SRC_ROOT}/${stream}/proc/COMPLETED ; ls *.${var}.*.nc 2>/dev/null`
      if [ "${file}" ] ; then
        echo "${stream}/proc/COMPLETED/${file} $var/$file" >> globus_lists/globus_transfer_list_${component}_${freq}.txt
        VAR_FOUND=TRUE
      fi
    done
    if [ "${VAR_FOUND}" != "TRUE" ] ; then
      echo "No file for ${var} in ${streams}"
    fi
  done
}

################

# Generate a file list to use with global transfer --batch
gen_popdiags_list() {
  # Inputs:
  #   None (will use global variable $MEMBER)
  # Output:
  #   globus_lists/globus_transfer_list_popdiags.txt is formatted for globus transfer --batch
  SRC_ROOT=${ARCHIVE_ROOT}/${MEMBER}
  DEST_ROOT=${CAMPAIGN_ROOT}/ocn/diags_pop
  rm -f globus_lists/globus_transfer_list_popdiags.txt
  for file in `cd ${SRC_ROOT} ; find . -name ${MEMBER}.pop.d*` ; do
    echo "${file} `basename $file`" >> globus_lists/globus_transfer_list_popdiags.txt
  done
}

################

# Generate a file list to use with global transfer --batch
gen_log_list() {
  # Inputs:
  #   None (will use global variable $MEMBER)
  # Output:
  #   globus_lists/globus_transfer_list_logs.txt is formatted for globus transfer --batch
  SRC_ROOT=${ARCHIVE_ROOT}/${MEMBER}
  DEST_ROOT=${CAMPAIGN_ROOT}/logs
  mkdir -p ${DEST_ROOT}/${MEMBER}
  rm -f globus_lists/globus_transfer_list_logs.txt
  for file in `cd ${SRC_ROOT} ; find . -name *.log.*` ; do
    echo "${file} ${MEMBER}/`basename $file`" >> globus_lists/globus_transfer_list_logs.txt
  done
}

################

# Generate a file list to use with global transfer --batch
gen_rest_list() {
  # Inputs:
  #   None (will use global variable $MEMBER)
  # Output:
  #   globus_lists/globus_transfer_list_rest.txt is formatted for globus transfer --batch
  SRC_ROOT=${ARCHIVE_ROOT}/${MEMBER}
  DEST_ROOT=${CAMPAIGN_ROOT}/restarts/no_pinatubo/
  for year in 2006 2026 ; do
    restdir="${year}-01-01-00000"
    if [ -d ${SRC_ROOT}/rest/${restdir} ] ; then
      mkdir -p ${DEST_ROOT}/${MEMBER}/${restdir}
      rm -f globus_lists/globus_transfer_list_rest.txt
      for file in `cd ${SRC_ROOT} ; find rest/${restdir} -type f` ; do
        echo "${file} ${MEMBER}/${restdir}/`basename $file`" >> globus_lists/globus_transfer_list_rest.txt
      done
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
  full_label=${label}_${compset}_${ensid}
  echo "Copying from ${SRC_ROOT} to ${DEST_ROOT} (${full_label})"
  globus transfer $OPTS $2 --label ${full_label} ${GLADE}:${SRC_ROOT} ${CAMPAIGN}:${DEST_ROOT} < globus_lists/globus_transfer_list_${label}.txt
}

###############
#             #
# MAIN SCRIPT #
#             #
###############

# Must have globus-cli installed and must be on casper
globus --version > /dev/null 2>&1 && GLOBUS_FOUND=TRUE

if [ ! "${GLOBUS_FOUND}" ] ; then
  echo "Can not find globus-cli!"
  exit 1
fi

if [ "`hostname | cut -d '-' -f 1`" != "casper" ] ; then
  echo "Can not run on `hostname`, need to run on Casper!"
  exit 1
fi

# Arguments are expected to be ensemble ids to loop through
if [ $# -eq 0 ] ; then
  ENSIDS=`seq -f "%03g" 1 35`
else
  ENSIDS="$@"
fi

mkdir -p globus_lists

# Set up some global variables for globus / file detection
GLADE="d33b3614-6d04-11e5-ba46-22000b92c6ec"
CAMPAIGN="6b5ab960-7bbf-11e8-9450-0a6d4e044368"
OPTS="--sync-level checksum --preserve-mtime --verify-checksum --notify on --batch"
ARCHIVE_ROOT=/glade/scratch/mlevy/archive
GLADE_ROOT=/glade/scratch/mlevy/reshaper
CAMPAIGN_ROOT=/glade/campaign/univ/udeo0005/cesmLE_no_pinatubo

# Activate globus
cmd="globus endpoint activate --web ${GLADE}"
echo "Activating globus..."
echo "\$ ${cmd}"
${cmd}
read -p "Log in to globus via the above URL then press enter to continue..."

for ensid in ${ENSIDS} ; do
  for compset in B20TRC5CNBDRD BRCP85C5CNBDRD ; do
    MEMBER=b.e11.${compset}_no_pinatubo.f09_g16.${ensid}
    if [ ! -d ${GLADE_ROOT}/${MEMBER} ] ; then
      echo "Can not find ${MEMBER} in ${GLADE_ROOT}"
      continue
    fi

    #################################################
    # Transfer all time series                      #
    # For each component, glob_ avoids over-writing #
    # global scope variables in gen_file_list       #
    #################################################

    # CAM output
    glob_component=atm
    for glob_stream in daily hourly6 monthly ; do
      echo "Compiling list for ${glob_stream} in ${glob_component}..."
      gen_file_list ${glob_component} ${glob_stream}
      transfer "${glob_component}_${glob_stream}"
    done

    # CICE output
    glob_component=ice
    for glob_stream in daily monthly ; do
      echo "Compiling list for ${glob_stream} in ${glob_component}..."
      gen_file_list ${glob_component} ${glob_stream}
      transfer "${glob_component}_${glob_stream}"
    done

    # CLM output
    glob_component=lnd
    for glob_stream in daily monthly ; do
      echo "Compiling list for ${glob_stream} in ${glob_component}..."
      gen_file_list ${glob_component} ${glob_stream}
      transfer "${glob_component}_${glob_stream}"
    done

    # POP output
    glob_component=ocn
    for glob_stream in annual daily monthly ; do
      echo "Compiling list for ${glob_stream} in ${glob_component}..."
      gen_file_list ${glob_component} ${glob_stream}
      transfer "${glob_component}_${glob_stream}"
    done

    # RTM output
    glob_component=rof
    for glob_stream in daily monthly ; do
      echo "Compiling list for ${glob_stream} in ${glob_component}..."
      gen_file_list ${glob_component} ${glob_stream}
      transfer "${glob_component}_${glob_stream}"
    done

    ##########################
    # Transfer restart files #
    ##########################
    gen_rest_list
    transfer "rest"

    ######################
    # Transfer log files #
    ######################
    gen_log_list
    transfer "logs"

    ########################
    # Transfer pop.d files #
    ########################
    gen_popdiags_list
    transfer "popdiags"

  done
done

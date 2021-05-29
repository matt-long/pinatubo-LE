#!/bin/bash

if [ $# -eq 0 ]; then
  ensid=001
else
  ensid=$1
fi
ROOTDIR=/glade/campaign/cesm/collections/cesmLE/CESM-CAM5-BGC-LE
for compset in B20TRC5CNBDRD BRCP85C5CNBDRD
do
  casename=b.e11.${compset}.f09_g16.${ensid}
  echo ${compset}
  echo "----"
  for component in atm ice lnd ocn rof
  do
    for freq in `ls ${ROOTDIR}/${component}/proc/tseries`
    do
      if [ "${freq}" == "hourly1" ]; then
        continue
      fi
      cd ${ROOTDIR}/${component}/proc/tseries/${freq}
      varcount=0
      for varname in `ls`
      do
        ls ${varname}/${casename}.* >/dev/null 2>&1  && varcount=$((varcount+1))
      done
      echo "${component}/proc/tseries/${freq}: ${varcount}"
    done
  done
  echo ""
done

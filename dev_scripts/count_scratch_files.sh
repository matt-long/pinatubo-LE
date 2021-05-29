#!/bin/bash

if [ $# -eq 0 ]; then
  ensid=001
else
  ensid=$1
fi
for compset in B20TRC5CNBDRD BRCP85C5CNBDRD
do
  echo ${compset}
  echo "----"
  cd /glade/scratch/mlevy/reshaper/b.e11.${compset}_no_pinatubo.f09_g16.${ensid}
  echo ${PWD}
  for dir in cam.h1 cam.h2 cam.h0 cice.h1 cice.h2 cice.h clm2.h1 clm2.h0 pop.h.ecosys.nyear1 "pop.*.nday1" pop.h rtm.h1 rtm.h0
  do
    if [ "${dir}" != "cice.h2" ]; then
      file_count=`find ${dir}/proc/COMPLETED -type f -name *.nc | wc -l`
    else
      file_count=0
    fi
    echo "${dir}: ${file_count}"
  done
  echo ""
done

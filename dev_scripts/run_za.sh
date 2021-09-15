#!/bin/bash

function submit_job () {
  job_name=$1
  file_in=$2
  file_out=$3
  echo "Submitting job to generate ${file_out}..."
  cmd="/glade/u/home/klindsay/bin/zon_avg/za -grid_file ${file_in} -kmt_file ${file_in} -rmask_file /glade/p/cgd/oce/people/klindsay/REGION_MASK/new_REGION_MASK_gx1v6.nc -o ${file_out} ${file_in}"
  qsub -N ${job_name} -A P93300606 -l select=1:ncpus=1 -l walltime=30:00 -q casper -j oe -m ea -- $cmd
}

###############
# MAIN SCRIPT #
###############

cwd=`pwd | xargs basename`
if [ "${cwd}" == "dev_scripts" ]; then
  echo "run this out of logs dir!"
  echo "cd logs ; ../run_za.sh"
  exit 1
fi

subcount=0
ncocount=0
lenscount=0
ourcount=0
ncea=/glade/u/apps/dav/opt/nco/4.9.5/gnu/9.1.0/bin/ncea

VARS_FOR_ZA="TEMP DIC DIC_ALT_CO2 O2 CFC11 CFC12 AOU IAGE ATM_CO2 ATM_ALT_CO2 FG_CO2 FG_ALT_CO2"
for compset in B20TRC5CNBDRD BRCP85C5CNBDRD; do
  if [ "$compset" == "B20TRC5CNBDRD" ]; then
    our_years=199001-200512
    LENS_years=198001-200512
    ncea_opt="-d time,-312," # hoping to get last 192 months = 16 years
    LENS_glob="*-200512"
  elif [ "$compset" == "BRCP85C5CNBDRD" ]; then
    our_years=200601-202512
    LENS_years=200601-202512
    ncea_opt="-d time,0,239" # first 240 months = 20 years
    LENS_glob="200601-*"
  fi

  ###############################
  # computing for original LENS #
  ###############################
  for caseid in {001..035}; do
      if [ ${caseid} -ge 3 ] && [ ${caseid} -le 8 ]; then
        continue
      fi
    for varname in ${VARS_FOR_ZA}; do
      job_name=${varname}_${caseid}_${LENS_years}

      # Pare down from full dataset to time period we are interested in
      in_dir=/glade/campaign/cesm/collections/cesmLE/CESM-CAM5-BGC-LE/ocn/proc/tseries/monthly/${varname}
      LENS_file=${in_dir}/b.e11.${compset}.f09_g16.${caseid}.pop.h.${varname}.${LENS_glob}.nc
      # Not all variables are output in all runs (e.g. no CFCs in RCP portion?)
      if [ ! -e ${LENS_file} ]; then
        echo "${LENS_file} does not exist; skipping"
        continue
      fi

      # tmp_file is for pulling out the 1990-2005 or 2006-2025 years from bigger time series
      tmp_file=/glade/scratch/mlevy/za_out/temp/${job_name}.nc
      out_dir=/glade/campaign/univ/udeo0005/cesmLE_no_pinatubo/ocn/proc/zonal_avg_tseries/${varname}
      mkdir -p ${out_dir}
      file_out=${out_dir}/b.e11.${compset}.f09_g16.${caseid}.pop.h.${varname}_zavg.${LENS_years}.nc
      # if za file already exists, don't do anything for this compset / case / variable
      if [ -e $file_out ]; then
        continue
      fi

      # either submit job to create 1990-2005 / 2006-2025 files or compute za
      if [ ! -e ${tmp_file} ]; then
        echo "Generating ${tmp_file} with NCO..."
        subcount=$((subcount+1))
        ncocount=$((ncocount+1))
        mkdir -p /glade/scratch/mlevy/za_out/temp
        qsub -N ${job_name}_ncea -A P93300606 -l select=1:ncpus=1 -l walltime=1:00:00 -q casper -j oe -m ea -- ${ncea} ${ncea_opt} ${LENS_file} ${tmp_file}
      else
        subcount=$((subcount+1))
        lenscount=$((lenscount+1))
        submit_job ${job_name}_LENS ${tmp_file} ${file_out}
      fi
    done
  done

  ##########################
  # computing for our runs #
  ##########################
  for caseid in {001..035}; do
    for varname in ${VARS_FOR_ZA}; do
      for exp in no_pinatubo cheyenne; do
        job_name=${varname}_${caseid}_${our_years}
        file_in=/glade/campaign/univ/udeo0005/cesmLE_${exp}/ocn/proc/tseries/monthly/${varname}/b.e11.${compset}_${exp}.f09_g16.${caseid}.pop.h.${varname}.${our_years}.nc
        if [ ! -e $file_in ]; then
          continue
        fi
        out_dir=/glade/campaign/univ/udeo0005/cesmLE_${exp}/ocn/proc/zonal_avg_tseries/${varname}
        mkdir -p ${out_dir}
        file_out=${out_dir}/b.e11.${compset}_${exp}.f09_g16.${caseid}.pop.h.${varname}_zavg.${our_years}.nc
        if [ -e $file_out ]; then
          continue
        fi
        subcount=$((subcount+1))
        ourcount=$((ourcount+1))
        submit_job ${job_name}_${exp} ${file_in} ${file_out}
      done
    done
  done
done

echo "Submitted ${subcount} job(s):"
echo "${ncocount} call(s) to ncea to pull specific years out of LENS time-series"
echo "${lenscount} call(s) to za for LENS runs"
echo "${ourcount} call(s) to za for no_pinatubo and / or cheyenne runs"

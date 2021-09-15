# pinatubo-LE
How did the Mt. Pinatubo eruption in 1991 affect the Earth system?

We are running and analyzing the Community Earth System Model Large Ensemble, version 1 ([CESM1-LE](http://www.cesm.ucar.edu/projects/community-projects/LENS/)) with forcing that excludes Mt. Pinatubo.
By comparing these runs with the full CESM-LE, we aim to quantify the effects the Mt. Pinatubo eruption explicitly.

## Conda environment
We are using `conda-lock` to ensure a reproducible environment. Please update the conda-lock files when updating the environment.

To create an environment from the lock file
```bash
conda create -n pinatubo-LE --file environment/conda-linux-64.lock
```

## Workflow

1. Run 1990 - 2005 with our modified forcing. Run `20thC_portion ###` from `case_gen_scripts/`, where `###` is the ensemble member id. Must be run on cheyenne!
1. Run 2006 - 2025 portion branching off from previous step. Run `RCP_portion ###` from `case_gen_scripts/`. Must be run on cheyenne!
1. Convert to time series. Run `run_all.py -m ###` from `data_reshaper/`. Must be run on casper!
1. Copy time series output to campaign storage. Run `transfer_to_campaign.sh ###` from `data_reshaper`. This script can take multiple ensemble ids as arguments. Must be run on casper from python environment that conrtains globus command line interface!
1. Verify transfer copied all files by running `count_campaign_files_our_run.sh ###` from `dev_scripts/`. Compare with a known-good case (001 - 012 only have 12 daily cice fields, rest have 20). Must be run on casper!
1. Generate zonal averages by running `run_za.sh` from `dev_scripts/`. This script will loop through each ensemble member that has time series on campaign and look to see if zonal averages have already been computed. If so, the member is skipped otherwise jobs are submitted to the queue. Must be run on casper.
1. When disk starts to fill up on campaign, I've been moving the cam 6-hourly output to `/glade/campaign/cgd/oce/people/mlevy/pinatubo_spillover/`

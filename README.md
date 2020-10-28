# pinatubo-LE
How did the Mt. Pinatubo eruption in 1991 affect the Earth system?

We are running and analyzing the Community Earth System Model Large Ensemble, version 1 (CESM1-LE) with forcing the excludes Mt. Pinatubo; 
by comparing these runs with the full CESM-LE, we aim to quantify the Pinatubo effects explicitly.

## Conda environment
We are using `conda-lock` to ensure a reproducible environment. Please update the conda-lock files when updating the environment.

To create an environment from the lock file
```bash
conda create -n pinatubo-LE --file environment/conda-linux-64.lock
```

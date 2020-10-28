#!/usr/bin/env bash

conda_env=$(grep name: environment.yml | awk '{print $2}')

source activate ${conda_env}

# generate the lockfiles
conda-lock -f environment.yml -p osx-64 -p linux-64

cat << EOF
# create an environment from the lockfile
conda-lock install [-p {prefix}|-n {name}] conda-linux-64.lock

# alternatively, use conda command directly
conda create -n my-locked-env --file conda-linux-64.lock
EOF
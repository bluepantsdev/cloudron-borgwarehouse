#!/bin/bash

set -eu

# set the environment variables
export CONFIG_PATH="/app/data/config"
export SSH_PATH="/app/data/.ssh"
export SSH_HOST="/app/data/ssh"
export TMP_PATH="/app/data/tmp"
export LOGS_PATH="/app/data/logs"
export REPO_PATH="/app/data/repo"

# create an array of paths
paths=($CONFIG_PATH $SSH_PATH $SSH_HOST $TMP_PATH $LOGS_PATH $REPO_PATH)

# loop through the paths and create them if they don't exist
for path in "${paths[@]}"; do
  if [[ ! -d $path ]]; then
    echo "Setting up directory $path..."
    mkdir -p $path
    echo "Done."
  fi
done

# run the docker-bw-init.sh script
./docker-bw-init.sh
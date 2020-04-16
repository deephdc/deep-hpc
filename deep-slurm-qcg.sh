#!/bin/bash
#
# -*- coding: utf-8 -*-
#
# Copyright (c) 2018 - 2020 Karlsruhe Institute of Technology - Steinbuch Centre for Computing
# This code is distributed under the MIT License
# Please, see the LICENSE file
#
# @author: vykozlov

###  INFO  #############################
# Script to submit a deep-oc application
# to slurm batch system via QCG
###

###
# This script's full path
# https://unix.stackexchange.com/questions/17499/get-path-of-current-script-when-executed-through-a-symlink/17500
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"
export UDOCKER_DOWNLOAD_LINK="https://github.com/indigo-dc/udocker/releases/download/devel3_1.2.4/udocker-1.2.4.tar.gz"

### (!) For testing (!)
### default is false
local_debug=false

### [!! Parameters defined in TOSCA ]
if [ "$local_debug" == "true" ]; then

    SLURM_PARTITION="standard"
    SLURM_EXTRA_OPTIONS=""

    DOCKER_IMAGE="deephdc/deep-oc-benchmarks_cnn:cpu-test"
    UDOCKER_RECREATE=false

    NUM_GPUS=0

    HOST_BASE_DIR=""
    APP_IN_OUT_BASE_DIR=""
    MOUNT_EXTRA_OPTIONS=""

    ## RCLONE_ settings
    RCLONE_CONF_HOST="$HOME/.config/rclone/rclone.conf"
    RCLONE_CONF_CONTAINER="/srv/.rclone/rclone.conf"
    RCLONE_TYPE="webdav"
    RCLONE_URL="https://nc.deep-hybrid-datacloud.eu/remote.php/webdav/"
    RCLONE_VENDOR="nextcloud"
    RCLONE_USER=""
    RCLONE_PASSWORD=""

    ## oneclient config
    ## ONEDATA WORKFLOW IS NOT VERIFIED! vk@2020-04-10
    ONECLIENT_ACCESS_TOKEN=""
    ONECLIENT_PROVIDER_HOST="oprov.ifca.es"
    ONEDATA_MOUNT_POINT="$HOME/onedata"

    UDOCKER_RUN_COMMAND="deepaas-cli train --num_epochs=0"
fi
### [/Parameters from TOSCA]

### [Fixed Parameters (for now)]
DATENOW=$(date +%y%m%d_%H%M%S)

## DOCKER
export DOCKER_IMAGE=$DOCKER_IMAGE

# let's define UDOCKER_CONTAINER MAINUALLY
UDOCKER_CONTAINER=${DOCKER_IMAGE}
if [[ "$UDOCKER_CONTAINER" =~ .*"/".* ]]; then
    UDOCKER_CONTAINER=$(echo $UDOCKER_CONTAINER| cut -d'/' -f 2)
fi
if [[ "$UDOCKER_CONTAINER" =~ "deep-oc-".* ]]; then
    UDOCKER_CONTAINER=${UDOCKER_CONTAINER#"deep-oc-"}
fi
# replace ":" with "-"
UDOCKER_CONTAINER=${UDOCKER_CONTAINER//:/-}
export UDOCKER_CONTAINER="${UDOCKER_CONTAINER}"

## SLURM
SLURM_NODES=1
SLURM_TASKS_PER_NODE=8
SLURM_LOG_DIR="${HOME}/tmp/slurm_jobs"
SLURM_LOG_FILE="${SLURM_LOG_DIR}/${DATENOW}-${UDOCKER_CONTAINER}.log"
SLURM_JOB2RUN="${SCRIPT_PATH}/deep-udocker-job.sh"

## FLAAT. IMPORTANT TO DISABLE!
FLAAT_DISABLE="yes"

## if HOST_BASE_DIR is NOT provided,
## define it as $HOME/deep-oc-apps/$UDOCKER_CONTAINER
if [ ${#HOST_BASE_DIR} -le 1 ]; then
    HOST_BASE_DIR="$HOME/deep-oc-apps/$UDOCKER_CONTAINER"
fi

## if APP_IN_OUT_BASE_DIR is NOT provided,
## define it as /mnt/${UDOCKER_CONTAINER}
## otherwise define it as /mnt/$UDOCKER_CONTAINER
if [ ${#APP_IN_OUT_BASE_DIR} -le 1 ]; then
    APP_IN_OUT_BASE_DIR="/mnt/${UDOCKER_CONTAINER}"
fi

## oneclient config
## ONEDATA WORKFLOW IS NOT VERIFIED! vk@2020-04-10
export ONECLIENT_ACCESS_TOKEN="$ONECLIENT_ACCESS_TOKEN"
export ONECLIENT_PROVIDER_HOST="$ONECLIENT_PROVIDER_HOST"
export ONEDATA_MOUNT_POINT="$ONEDATA_MOUNT_POINT"

## Set UDOCKER_RUN_COMMAND, ALL OTHER PARAMETERS MUST BE CORRECTLY SET BEFORE!
# allows passing variable names and expanding them here
udocker_run_command_expanded=$(eval echo -e "$UDOCKER_RUN_COMMAND")
export UDOCKER_RUN_COMMAND="$udocker_run_command_expanded"

### [/Fixed Parameters set]


### Now ready to configure options for udocker and the final submission to slurm
## Configure UDOCKER_OPTIONS
# Check if HOST_BASE_DIR is set and exists
if [ ${#HOST_BASE_DIR} -gt 1 ]; then
    [[ ! -d "$HOST_BASE_DIR" ]] && mkdir -p "$HOST_BASE_DIR"
    MOUNT_OPTIONS="-v ${HOST_BASE_DIR}:${APP_IN_OUT_BASE_DIR} "
else 
    MOUNT_OPTIONS=""
fi

ENV_OPTIONS=""
# Define RCLONE config if user and password are provided,
# otherwise mount rclone.conf from the host
if [ ${#RCLONE_USER} -gt 8 ] && [ ${#RCLONE_PASSWORD} -gt 8 ]; then
    ENV_OPTIONS+="-e RCLONE_CONFIG=${RCLONE_CONF_CONTAINER} \
-e RCLONE_CONFIG_RSHARE_TYPE=${RCLONE_TYPE} \
-e RCLONE_CONFIG_RSHARE_URL=${RCLONE_URL} \
-e RCLONE_CONFIG_RSHARE_VENDOR=${RCLONE_VENDOR} \
-e RCLONE_CONFIG_RSHARE_USER=${RCLONE_USER} \
-e RCLONE_CONFIG_RSHARE_PASS=${RCLONE_PASSWORD}"
else
    ENV_OPTIONS+="-e RCLONE_CONFIG=${RCLONE_CONF_CONTAINER}"
    if [ -f "$RCLONE_CONF_HOST" ]; then
        MOUNT_OPTIONS+=" -v $(dirname ${RCLONE_CONF_HOST}):$(dirname ${RCLONE_CONF_CONTAINER})"
    fi
fi

# Mount extra directories if defined
[[ ${#MOUNT_EXTRA_OPTIONS} -ge 5 ]] && MOUNT_OPTIONS+=" ${MOUNT_EXTRA_OPTIONS}"

# Add APP_INPUT_OUTPUT_BASE_DIR environment, if APP_IN_OUT_BASE_DIR is set
if [ ${#APP_IN_OUT_BASE_DIR} -gt 5 ]; then
    ENV_OPTIONS+=" -e APP_INPUT_OUTPUT_BASE_DIR=${APP_IN_OUT_BASE_DIR}"
fi

# Add flaat env setting
ENV_OPTIONS+=" -e DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER=$FLAAT_DISABLE"

export MOUNT_OPTIONS=${MOUNT_OPTIONS}
export UDOCKER_OPTIONS="${ENV_OPTIONS} ${MOUNT_OPTIONS}"

### Configure SLURM submission
# Check if SLURM_LOG_DIR exists
[[ ! -d "$SLURM_LOG_DIR" ]] && mkdir -p "$SLURM_LOG_DIR"

#... UDOCKER_USE_GPU + slurm's --gres
export UDOCKER_USE_GPU=false
if [ $NUM_GPUS -gt 0 ]; then
    export UDOCKER_USE_GPU=true
    SLURM_EXTRA_OPTIONS+=" --gres=gpu:${NUM_GPUS}"
fi

SLURM_OPTIONS="--partition=${SLURM_PARTITION} \
--nodes=${SLURM_NODES} \
--ntasks-per-node=${SLURM_TASKS_PER_NODE} \
--job-name=${UDOCKER_CONTAINER} \
--output=${SLURM_LOG_FILE}"

[[ ${#SLURM_EXTRA_OPTIONS} -ge 1 ]] && SLURM_OPTIONS+=" ${SLURM_EXTRA_OPTIONS}"

# Final submission to SLURM
sbatch ${SLURM_OPTIONS} ${SLURM_JOB2RUN}

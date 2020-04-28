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

## FLAAT. IMPORTANT TO DISABLE!
FLAAT_DISABLE="yes"

### FYI:
# APP_IN_OUT_BASE_DIR has to be set explicitely, otherwise not used!

## oneclient config
export ONECLIENT_ACCESS_TOKEN="$ONECLIENT_ACCESS_TOKEN"
export ONECLIENT_PROVIDER_HOST="$ONECLIENT_PROVIDER_HOST"
# generate HOST_ONEDATA_MOUNT_POINT
export HOST_ONEDATA_MOUNT_POINT="${HOME}/onedata-"$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')


## Set UDOCKER_RUN_COMMAND, ALL OTHER PARAMETERS MUST BE CORRECTLY SET BEFORE!
# allows passing variable names and expanding them here
udocker_run_command_expanded=$(eval echo -e "$UDOCKER_RUN_COMMAND")
export UDOCKER_RUN_COMMAND="$udocker_run_command_expanded"

### [/Fixed Parameters set]


### Now ready to configure options for udocker and the final submission to slurm
## Configure UDOCKER_OPTIONS

MOUNT_OPTIONS=""
# Check if ONECLIENT_ACCESS_TOKEN is provided
if [ ${#ONECLIENT_ACCESS_TOKEN} -gt 1 ]; then
    # check if ONEDATA_MOUNT_POINT is given, if not: /mnt/onedata
    if [ ${#ONEDATA_MOUNT_POINT} -le 1 ]; then
        ONEDATA_MOUNT_POINT=/mnt/onedata
    fi
    MOUNT_OPTIONS+=" -v ${HOST_ONEDATA_MOUNT_POINT}:${ONEDATA_MOUNT_POINT}"
fi
export ONEDATA_MOUNT_POINT

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

# Add APP_INPUT_OUTPUT_BASE_DIR environment, if APP_IN_OUT_BASE_DIR is set
if [ ${#APP_IN_OUT_BASE_DIR} -gt 5 ]; then
    ENV_OPTIONS+=" -e APP_INPUT_OUTPUT_BASE_DIR=${APP_IN_OUT_BASE_DIR}"
fi

# Add flaat env setting
ENV_OPTIONS+=" -e DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER=$FLAAT_DISABLE"

UDOCKER_OPTIONS="${ENV_OPTIONS} ${MOUNT_OPTIONS}"
# Pass extra options if defined
[[ ${#UDOCKER_EXTRA_OPTIONS} -ge 5 ]] && UDOCKER_OPTIONS+=" ${UDOCKER_EXTRA_OPTIONS}"

export UDOCKER_OPTIONS=${UDOCKER_OPTIONS}
# for logging
export MOUNT_OPTIONS=${MOUNT_OPTIONS}

### Configure SLURM submission
# Check if SLURM_LOG_DIR exists
[[ ! -d "$SLURM_LOG_DIR" ]] && mkdir -p "$SLURM_LOG_DIR"

#... UDOCKER_USE_GPU + slurm's --gres
export UDOCKER_USE_GPU=false
if [ $NUM_GPUS -gt 0 ]; then
    export UDOCKER_USE_GPU=true
fi

# Final submission
curl https://raw.githubusercontent.com/deephdc/deep-hpc/qcg/deep-udocker-job.sh | /bin/bash

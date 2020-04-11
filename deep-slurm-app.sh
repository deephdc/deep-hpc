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
# to slurm batch system
# 
###

###
# This script full path
# https://unix.stackexchange.com/questions/17499/get-path-of-current-script-when-executed-through-a-symlink/17500
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"

### INITIALIZATION OF PARAMETERS
DATENOW=$(date +%y%m%d_%H%M%S)

SCRIPT_INI="${SCRIPT_PATH}/deep-slurm-app.ini"

##... SLURM ...##
SLURM_PARTITION=""
SLURM_LOG=""
SLURM_LOG_DIR="${HOME}/tmp/slurm_jobs"
SLURM_JOB2RUN="${SCRIPT_PATH}/deep-udocker-job.sh"

DOCKER_IMAGE=""
UDOCKER_CONTAINER=""
UDOCKER_RECREATE=""

NUM_GPUS=""

HOST_BASE_DIR=""
UDOCKER_RUN_COMMAND=""

### USAGE and PARSE SCRIPT FLAGS
function usage()
{
    shopt -s xpg_echo
    echo "Usage: $0 <options> \n
    Options:
    -h|--help \t\t This help message
    -c|--cmd \t\t Command to run inside the Docker image
    -d|--docker \t Docker image to run
    -g|--gpus \t\t Number of GPUs to request
    -i|--ini \t\t INI file to load for the defautl settings (full path!)
    -l|--log \t\t If provided, activates SLURM output to the file (see ${slurm_log_dir} directory)
    -p|--partition \t Choose which cluster partition to use (e.g. CPU: 'standard', GPU: 'tesla')
    -r|--recreate \t If provided, it forces re-creation of the container
    -v|--volume \t Host volume (directory), with e.g. ~/data and ~/models, to be mounted inside the container" 1>&2; exit 0;
}

function check_arguments()
{
    OPTIONS=h,c:,d:,g:,i:,l,p:,r,v:
    LONGOPTS=help,cmd:,docker:,gpus:,ini:,log,partition:,recreate,volume:
    # https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
    #set -o errexit -o pipefail -o noclobber -o nounset
    set  +o nounset
    ! getopt --test > /dev/null
    if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
        echo '`getopt --test` failed in this environment.'
        exit 1
    fi

    # -use ! and PIPESTATUS to get exit code with errexit set
    # -temporarily store output to be able to check for errors
    # -activate quoting/enhanced mode (e.g. by writing out “--options”)
    # -pass arguments only via   -- "$@"   to separate them correctly
    ! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        # e.g. return value is 1
        #  then getopt has complained about wrong arguments to stdout
        exit 2
    fi
    # read getopt’s output this way to handle the quoting right:
    eval set -- "$PARSED"

    if [ "$1" == "--" ]; then
        echo "[INFO] No arguments provided, using defaults."
    fi
    # now enjoy the options in order and nicely split until we see --
    while true; do
        case "$1" in
            -h|--help)
                usage
                shift
                ;;
            -c|--cmd)
                export UDOCKER_RUN_COMMAND="$2"
                shift 2
                ;;
            -d|--docker)
                export DOCKER_IMAGE="$2"
                shift 2
                ;;
            -g|--gpus)
                NUM_GPUS="$2"
                shift 2
                ;;
            -i|--ini)
                SCRIPT_INI="$2"
                shift 2
                ;;
            -l|--log)
                SLURM_LOG=true
                shift
                ;;
            -p|--partition)
                SLURM_PARTITION="$2"
                shift 2
                ;;
            -r|--recreate)
                export UDOCKER_RECREATE=true
                shift
                ;;
            -v|--volume)
                HOST_BASE_DIR="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                break
                ;;
            esac
        done
}

check_arguments "$0" "$@"

### DERIVE NECESSARY PARAMETERS FROM THE COMMAND LINE AND INI FILE
echo "[INFO] Loading defaults from ${SCRIPT_INI}"
source "${SCRIPT_INI}"

## If a parameter not set from the command line, take its value from the INI file
## SLURM configuration
[[ ${#SLURM_PARTITION} -lt 1 ]] && SLURM_PARTITION=$slurm_partition
[[ ${#SLURM_LOG} -lt 1 ]] && SLURM_LOG=$slurm_log
SLURM_NODES=$slurm_nodes
SLURM_TASKS_PER_NODE=$slurm_tasks_per_node
SLURM_TIME=$slurm_time
SLURM_EXTRA_OPTIONS=$slurm_extra_options

## Docker image and container
[[ ${#DOCKER_IMAGE} -le 1 ]] && export DOCKER_IMAGE=$docker_image
[[ ${#UDOCKER_RECREATE} -le 1 ]] && export UDOCKER_RECREATE=$udocker_recreate

## if udocker_container is provided in the INI, use it,
## otherwise derive it from the docker image name
if [ ${#udocker_container} -le 1 ]; then
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
else
    export UDOCKER_CONTAINER="${udocker_container}"
fi

[[ ${#NUM_GPUS} -lt 1 ]] && NUM_GPUS=$num_gpus

FLAAT_DISABLE=$flaat_disable

## oneclient config
## ONEDATA WORKFLOW IS NOT VERIFIED! vk@2020-04-10
export ONECLIENT_ACCESS_TOKEN="$oneclient_access_token"
export ONECLIENT_PROVIDER_HOST="$oneclient_provider_host"
export ONEDATA_MOUNT_POINT="$onedata_mount_point"

[[ ${#HOST_BASE_DIR} -lt 1 ]] && HOST_BASE_DIR=$host_base_dir

## if app_in_out_base_dir is provided in the INI, use it,
## otherwise define it as /mnt/$UDOCKER_CONTAINER
if [ ${#app_in_out_base_dir} -le 1 ]; then
    APP_IN_OUT_BASE_DIR="/mnt/${UDOCKER_CONTAINER}"
else
    APP_IN_OUT_BASE_DIR="$app_in_out_base_dir"
fi

MOUNT_EXTRA_OPTIONS="$mount_extra_options"

## Set RCLONE_ settings from the INI file
RCLONE_CONF_HOST="$rclone_conf_host"
RCLONE_CONF_CONTAINER="$rclone_conf_container"
RCLONE_TYPE="$rclone_type"
RCLONE_URL="$rclone_url"
RCLONE_VENDOR="$rclone_vendor"
RCLONE_USER="$rclone_user"
RCLONE_PASSWORD="$rclone_password"

## Set UDOCKER_RUN_COMMAND, if it is not set from CLI
## ALL OTHER PARAMETERS MUST BE CORRECTLY SET BEFORE!
if [ ${#UDOCKER_RUN_COMMAND} -le 1 ]; then
  unset udocker_run_command
  source "${SCRIPT_INI}"
  export UDOCKER_RUN_COMMAND="$udocker_run_command"
else
  # allows passing variable names and expanding them here
  udocker_run_command_expanded=$(eval echo -e "$UDOCKER_RUN_COMMAND")
  export UDOCKER_RUN_COMMAND="$udocker_run_command_expanded"
fi
### [/Parameters configured]

### Now ready to configure options for udocker and the final submission to slurm
## Configure UDOCKER_OPTIONS
# Check if HOST_BASE_DIR is set and exists
if [ ${#HOST_BASE_DIR} -gt 1 ]; then
    [[ ! -d "$HOST_BASE_DIR" ]] && mkdir -p "$HOST_BASE_DIR"
    mount_options="-v ${HOST_BASE_DIR}:${APP_IN_OUT_BASE_DIR} "
else 
    mount_options=""
fi

env_options=""
# Define RCLONE config if user and password are provided,
# otherwise mount rclone.conf from the host
if [ ${#RCLONE_USER} -gt 8 ] && [ ${#RCLONE_PASSWORD} -gt 8 ]; then
    env_options+="-e RCLONE_CONFIG=${RCLONE_CONF_CONTAINER} \
-e RCLONE_CONFIG_RSHARE_TYPE=${RCLONE_TYPE} \
-e RCLONE_CONFIG_RSHARE_URL=${RCLONE_URL} \
-e RCLONE_CONFIG_RSHARE_VENDOR=${RCLONE_VENDOR} \
-e RCLONE_CONFIG_RSHARE_USER=${RCLONE_USER} \
-e RCLONE_CONFIG_RSHARE_PASS=${RCLONE_PASSWORD}"
else
    env_options+="-e RCLONE_CONFIG=${RCLONE_CONF_CONTAINER}"
    if [ -f "$RCLONE_CONF_HOST" ]; then
        mount_options+=" -v $(dirname ${RCLONE_CONF_HOST}):$(dirname ${RCLONE_CONF_CONTAINER})"
    fi
fi

# Mount extra directories if defined
[[ ${#MOUNT_EXTRA_OPTIONS} -ge 5 ]] && mount_options+=" ${MOUNT_EXTRA_OPTIONS}"

# Add APP_INPUT_OUTPUT_BASE_DIR environment, if APP_IN_OUT_BASE_DIR is set
if [ ${#APP_IN_OUT_BASE_DIR} -gt 5 ]; then
    env_options+=" -e APP_INPUT_OUTPUT_BASE_DIR=${APP_IN_OUT_BASE_DIR}"
fi

# Add flaat env setting
env_options+=" -e DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER=$FLAAT_DISABLE"

export UDOCKER_OPTIONS="${env_options} ${mount_options}"

### Configure SLURM submission
# Check if SLURM_LOG_DIR exists
[[ ! -d "$SLURM_LOG_DIR" ]] && mkdir -p "$SLURM_LOG_DIR"

# Default log file
slurm_log_file="${SLURM_LOG_DIR}/${DATENOW}-${UDOCKER_CONTAINER}.log"

echo "=== DATE: ${DATENOW}" >>${slurm_log_file}
echo "== DOCKER_IMAGE: ${DOCKER_IMAGE}" >>${slurm_log_file}
echo "== UDOCKER_CONTAINER: ${UDOCKER_CONTAINER}" >>${slurm_log_file}
# [!] Comment UDOCKER_OPTIONS, as this may publish AUTHENTICATION info:
# echo "== UDOCKER_OPTIONS: ${UDOCKER_OPTIONS}" >>${slurm_log_file}
echo "== UDOCKER_RUN_COMMAND: ${UDOCKER_RUN_COMMAND}" >>${slurm_log_file}

SLURM_OPTIONS="--partition=${SLURM_PARTITION} \
--nodes=${SLURM_NODES} \
--ntasks-per-node=${SLURM_TASKS_PER_NODE} \
--time=${SLURM_TIME} \
--job-name=${UDOCKER_CONTAINER}"

[[ ${#SLURM_EXTRA_OPTIONS} -ge 1 ]] && SLURM_OPTIONS+=" ${SLURM_EXTRA_OPTIONS}"

#... UDOCKER_USE_GPU + slurm's --gres
export UDOCKER_USE_GPU=false
if [ $NUM_GPUS -gt 0 ]; then
    export UDOCKER_USE_GPU=true
    SLURM_OPTIONS+=" --gres=gpu:${NUM_GPUS}"
    echo "== [INFO] GPU usage is activated" >>${slurm_log_file}
fi

# Add job log, if SLURM_LOG is true
if echo ${SLURM_LOG}| grep -iqF "true"; then
    SLURM_OPTIONS+=" --output=${slurm_log_file}"
fi

echo "== SLURM OPTIONS: ${SLURM_OPTIONS}" >>${slurm_log_file}

# Final submission to SLURM
sbatch ${SLURM_OPTIONS} ${SLURM_JOB2RUN}

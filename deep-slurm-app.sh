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

### INITIALIZE FIXED PARAMETERS
DATENOW=$(date +%y%m%d_%H%M%S)
export UDOCKER_DOWNLOAD_LINK="https://github.com/indigo-dc/udocker/releases/download/devel3_1.2.4/udocker-1.2.4.tar.gz"

SCRIPT_INI="${SCRIPT_PATH}/deep-slurm-app.ini"
NO_CLI_OPTS=false

##... SLURM ...##
SLURM_LOG_DIR="${HOME}/tmp/slurm_jobs"
SLURM_JOB2RUN="${SCRIPT_PATH}/deep-udocker-job.sh"

## ports
deepaasPORT=5000
monitorPORT=6006
jupyterPORT=8888

###

### Some DEFAULTS
HOST_DIR_MOUNT_POINT_0="/mnt/host"
ONEDATA_MOUNT_POINT_0="/mnt/onedata"
###


### USAGE and PARSE SCRIPT FLAGS
function usage()
{
    shopt -s xpg_echo
    echo "Usage: $0 <options> \n
    Options:
    -h|--help \t\t This help message
    -b|--base-dir \t Base directory for input and output data (e.g. data, models) *inside the container* (APP_IN_OUT_BASE_DIR)
    -c|--cmd \t\t Command to run inside the Docker image
    -d|--docker \t Docker image to run
    -g|--gpus \t\t Number of GPUs to request
    -i|--ini \t\t INI file to load for the default settings (full path!)
    -l|--log \t\t If provided, activates SLURM output to the file (see ${slurm_log_dir} directory)
    -p|--partition \t Choose which cluster partition to use (e.g. CPU: 'standard', GPU: 'tesla')
    -r|--recreate \t If provided, it forces re-creation of the container
    -v|--volume \t Host volume (directory), with e.g. ~/data and ~/models, to be mounted inside the container" 1>&2; exit 0;
}

function check_arguments()
{
    OPTIONS=h,b:,c:,d:,g:,i:,l,p:,r,v:
    LONGOPTS=help,base-dir:,cmd:,docker:,gpus:,ini:,log,partition:,recreate,volume:
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
        NO_CLI_OPTS=true
    fi
    # now enjoy the options in order and nicely split until we see --
    while true; do
        case "$1" in
            -h|--help)
                usage
                shift
                ;;
            -b|--base-dir)
                app_in_out_base_dir="$2"
                shift 2
                ;;
            -c|--cmd)
                udocker_run_command="$2"
                shift 2
                ;;
            -d|--docker)
                docker_image="$2"
                shift 2
                ;;
            -g|--gpus)
                num_gpus="$2"
                shift 2
                ;;
            -i|--ini)
                script_ini="$2"
                shift 2
                ;;
            -l|--log)
                slurm_log=true
                shift
                ;;
            -p|--partition)
                slurm_partition="$2"
                shift 2
                ;;
            -r|--recreate)
                udocker_recreate=true
                shift
                ;;
            -v|--volume)
                host_dir="$2"
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

### DERIVE NECESSARY PARAMETERS FROM THE INI FILE AND COMMAND LINE
[[ ${#script_ini} -gt 1 ]] && SCRIPT_INI="${script_ini}"
echo "[INFO] Loading defaults from ${SCRIPT_INI}"
[[ "${NO_CLI_OPTS}" -eq "true" ]] && echo "      ...and update them with the provided in CLI values"
source "${SCRIPT_INI}"

## If a parameter is updated from the command line, use its new value
## SLURM configuration
[[ ${#slurm_partition} -gt 1 ]] && SLURM_PARTITION=$slurm_partition
[[ ${#slurm_log} -gt 1 ]] && SLURM_LOG=$slurm_log

## Docker image and container
[[ ${#docker_image} -gt 1 ]] && export DOCKER_IMAGE=$docker_image
export DOCKER_IMAGE=$DOCKER_IMAGE
[[ ${#udocker_recreate} -gt 1 ]] && export UDOCKER_RECREATE=$udocker_recreate
export UDOCKER_RECREATE=$UDOCKER_RECREATE

## if UDOCKER_CONTAINER is provided in the INI, use it,
## otherwise derive it from the docker image name
if [ ${#UDOCKER_CONTAINER} -le 1 ]; then
    UDOCKER_CONTAINER=${DOCKER_IMAGE}
    if [[ "$UDOCKER_CONTAINER" =~ .*"/".* ]]; then
        UDOCKER_CONTAINER=$(echo $UDOCKER_CONTAINER| cut -d'/' -f 2)
    fi
    if [[ "$UDOCKER_CONTAINER" =~ "deep-oc-".* ]]; then
        UDOCKER_CONTAINER=${UDOCKER_CONTAINER#"deep-oc-"}
    fi
    # replace ":" with "-"
    UDOCKER_CONTAINER=${UDOCKER_CONTAINER//:/-}
fi
export UDOCKER_CONTAINER="${UDOCKER_CONTAINER}"

[[ ${#num_gpus} -ge 1 ]] && NUM_GPUS=$num_gpus

## ONEDATA
export ONECLIENT_ACCESS_TOKEN="${ONECLIENT_ACCESS_TOKEN}"
export ONECLIENT_PROVIDER_HOST="${ONECLIENT_PROVIDER_HOST}"
# generate HOST_ONEDATA_MOUNT_POINT
export HOST_ONEDATA_MOUNT_POINT="${HOME}/onedata-"$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')

## use "/mnt/onedata" if ONEDATA_MOUNT_POINT is empty in the INI
[[ ${#ONEDATA_MOUNT_POINT} -le 1 ]] && ONEDATA_MOUNT_POINT="${ONEDATA_MOUNT_POINT_0}"
export ONEDATA_MOUNT_POINT=$ONEDATA_MOUNT_POINT

## define HOST_DIR, if given as CLI option
[[ ${#host_dir} -gt 1 ]] &&  HOST_DIR="${host_dir}"

## use "/mnt/host" if HOST_DIR_MOUNT_POINT is empty in the INI
[[ ${#HOST_DIR_MOUNT_POINT} -le 1 ]] && HOST_DIR_MOUNT_POINT="${HOST_DIR_MOUNT_POINT_0}"

## Update APP_IN_OUT_BASE_DIR if CLI option is provided
[[ ${#app_in_out_base_dir} -gt 1 ]] && APP_IN_OUT_BASE_DIR="$app_in_out_base_dir"


## set UDOCKER_RUN_COMMAND
## all other parameters must be correctly set before!
## update UDOCKER_RUN_COMMAND, if provided in CLI
[[ ${#udocker_run_command} -gt 1 ]] && UDOCKER_RUN_COMMAND="$udocker_run_command"

# following allows passing variable names and expanding them
# carefull with spaces, use '\"<parameter_with_space>\"'
udocker_run_command_expanded="$(eval echo -e "${UDOCKER_RUN_COMMAND}")"
UDOCKER_RUN_COMMAND="$udocker_run_command_expanded"

export UDOCKER_RUN_COMMAND="$UDOCKER_RUN_COMMAND"

### [/Parameters configured]


### [Configure UDOCKER_OPTIONS]
### Now ready to configure options for udocker and the final submission to slurm

MOUNT_OPTIONS=""
# Check if HOST_DIR is set and exists
if [ ${#HOST_DIR} -gt 1 ]; then
    [[ ! -d "$HOST_DIR" ]] && mkdir -p "$HOST_DIR"
    MOUNT_OPTIONS+="-v ${HOST_DIR}:${HOST_DIR_MOUNT_POINT} "
fi

# Check if ONECLIENT_ACCESS_TOKEN is provided
if [ ${#ONECLIENT_ACCESS_TOKEN} -gt 8 ]; then
    # check if the local mount point exists
    [[ ! -d "${HOST_ONEDATA_MOUNT_POINT}" ]] && mkdir -p "${HOST_ONEDATA_MOUNT_POINT}"
    MOUNT_OPTIONS+=" -v ${HOST_ONEDATA_MOUNT_POINT}:${ONEDATA_MOUNT_POINT}"
fi

# define ports
export PORTS_OPTIONS="-p ${deepaasPORT}:5000 -p ${monitorPORT}:6006 -p ${jupyterPORT}:8888 "

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

# Add jupyterPASSWORD, in case provided:
if [ ${#jupyterPASSWORD} -gt 8 ]; then
    ENV_OPTIONS+=" -e jupyterPASSWORD=${jupyterPASSWORD}"
fi

UDOCKER_OPTIONS="${PORTS_OPTIONS} ${ENV_OPTIONS} ${MOUNT_OPTIONS}"
# Pass extra options if defined
[[ ${#UDOCKER_EXTRA_OPTIONS} -ge 5 ]] && UDOCKER_OPTIONS+=" ${UDOCKER_EXTRA_OPTIONS}"

export UDOCKER_OPTIONS=${UDOCKER_OPTIONS}
# for logging
export MOUNT_OPTIONS=${MOUNT_OPTIONS}

### Configure SLURM submission
#... UDOCKER_USE_GPU + slurm's --gres
export UDOCKER_USE_GPU=false
if [ $NUM_GPUS -gt 0 ]; then
    export UDOCKER_USE_GPU=true
    SLURM_EXTRA_OPTIONS+=" --gres=gpu:${NUM_GPUS}"
fi

SLURM_OPTIONS="--partition=${SLURM_PARTITION} \
--nodes=${SLURM_NODES} \
--ntasks-per-node=${SLURM_TASKS_PER_NODE} \
--job-name=${UDOCKER_CONTAINER}"

# Add job log, if SLURM_LOG is true
if echo ${SLURM_LOG}| grep -iqF "true"; then
    # Check if SLURM_LOG_DIR exists
    [[ ! -d "$SLURM_LOG_DIR" ]] && mkdir -p "$SLURM_LOG_DIR"
    # Default log file
    slurm_log_file="${SLURM_LOG_DIR}/${DATENOW}-${UDOCKER_CONTAINER}.log"
    SLURM_OPTIONS+=" --output=${slurm_log_file}"
fi

[[ ${#SLURM_EXTRA_OPTIONS} -ge 1 ]] && SLURM_OPTIONS+=" ${SLURM_EXTRA_OPTIONS}"

## DEBUG
# echo "${UDOCKER_RUN_COMMAND}"
# echo "${UDOCKER_OPTIONS}"
# echo "${SLURM_OPTIONS}"
##

# Final submission to SLURM
sbatch ${SLURM_OPTIONS} ${SLURM_JOB2RUN}

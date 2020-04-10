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
# Used parameters for SBATCH 
# --partition standard | tesla
# --nodes=1
# --ntasks-per-node=24
# --time=3:00:00
# --job-name=deep-oc-app
# --output
# --gres=gpu:1  # if num_gpus>0 is requisted
#########################################

# Script full path
# https://unix.stackexchange.com/questions/17499/get-path-of-current-script-when-executed-through-a-symlink/17500
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"
DATENOW=$(date +%y%m%d_%H%M%S)

### DEPLOYMENT MAIN CONFIGURATION (User Action!)
##... SLURM CONFIG ...##
# For CPU: standard, For GPU: tesla
slurm_partition="standard"
slurm_nodes=1
slurm_time="12:00:00"
slurm_tasks_per_node=8
slurm_log_dir="${HOME}/tmp/slurm_jobs"
slurm_log=false
slurm_job2run="${SCRIPT_PATH}/deep-udocker-job.sh"
##

## Docker image and container
export DOCKER_IMAGE="deephdc/deep-oc-benchmarks_cnn:gpu-test"
export UDOCKER_RECREATE=False
# OPTIONAL! UDOCKER_CONTAINER is automatically derived from DOCKER_IMAGE later
export UDOCKER_CONTAINER=""
##

num_gpus=0
flaat_disable="yes"

##... oneclient ..##
## ONEDATA WORKFLOW IS NOT VERIFIED! vk@2020-04-10
export ONECLIENT_ACCESS_TOKEN="MDXXX"
# options: 
# oprov.ifca.es 
# oneprovider.fedcloud.eu
# cloud-90-147-75-163.cloud.ba.infn.it
export ONECLIENT_PROVIDER_HOST="oprov.ifca.es"
export ONEDATA_MOUNT_POINT="$HOME/onedata"
##

host_base_dir="${HOME}/deep-oc-apps"
mount_extra_options=""

##... rclone config ...##
rclone_conf_host="${HOME}/.config/rclone/rclone.conf"
rclone_conf_container="/srv/.rclone/rclone.conf"
rclone_vendor="nextcloud"
rclone_type="webdav"
rclone_url="https://nc.deep-hybrid-datacloud.eu/remote.php/webdav/"
rclone_user="DEEP-XXX"
rclone_password="jXXX"
##

## put the following in functions to be able to update later,
## if some parameters are re-configured from the command line (CLI)
function update_inputs()
{
   app_in_out_base_dir="/mnt/${UDOCKER_CONTAINER}"
}

function set_udocker_run_command()
{
   # run_command configuration
   export UDOCKER_RUN_COMMAND="deepaas-cli \
--deepaas_method_output=${app_in_out_base_dir}/${DATENOW}-train.out \
train \
--batch_size_per_device=32 \
--num_epochs=0 \
--num_gpus=${num_gpus} \
--model=\"resnet50 (ImageNet)\" \
--dataset=\"Synthetic data\" \
--evaluation=true"
}

##
### END OF THE DEPLOYMENT MAIN CONFIG ###

### USAGE and PARSE SCRIPT FLAGS ###
function usage()
{
    shopt -s xpg_echo
    echo "Usage: $0 <options> \n
    Options:
    -h|--help \t\t This help message
    -c|--cmd \t\t Command to run inside the Docker image
    -d|--docker \t Docker image to run
    -g|--gpus \t\t Number of GPUs to request
    -l|--log \t\t If provided, activates SLURM output to the file (see ${slurm_log_dir} directory)
    -p|--partition \t Choose which cluster partition to use (e.g. CPU: 'standard', GPU: 'tesla')
    -r|--recreate \t If provided, it forces re-creation of the container
    -v|--volume \t Host volume (directory), with e.g. ~/data and ~/models, to be mounted inside the container" 1>&2; exit 0;
}

function check_arguments()
{
    OPTIONS=h,c:,d:,g:,l,p:,r,v:
    LONGOPTS=help,cmd:,docker:,gpus:,log,partition:,recreate,volume:
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
                num_gpus="$2"
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
                export UDOCKER_RECREATE=true
                shift
                ;;
            -v|--volume)
                host_base_dir="$2"
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

### NEXT IS DERIVED FROM THE OPTIONS ABOVE
### Derive UDOCKER_CONTAINER name from the image name:
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
    export UDOCKER_CONTAINER=${UDOCKER_CONTAINER}
fi
##

# Update inputs, in case they were re-configured from CLI
update_inputs

### Set udocker_run_command, if it is not set from CLI
if [ ${#UDOCKER_RUN_COMMAND} -le 1 ]; then
    set_udocker_run_command
fi
###

### Configure UDOCKER_OPTIONS ###
# Check if host_base_dir exists
if [ ! -d "$host_base_dir" ]; then
    mkdir -p "$host_base_dir"
fi

mount_options="-v ${host_base_dir}:${app_in_out_base_dir} "

env_options=""
# Define RCLONE config if user and password provided,
# otherwise mount rclone.conf from the host
if [ ${#rclone_user} -gt 8 ] && [ ${#rclone_password} -gt 8 ]; then
    env_options+="-e RCLONE_CONFIG=${rclone_conf_container} \
-e RCLONE_CONFIG_RSHARE_TYPE=${rclone_type} \
-e RCLONE_CONFIG_RSHARE_URL=${rclone_url} \
-e RCLONE_CONFIG_RSHARE_VENDOR=${rclone_vendor} \
-e RCLONE_CONFIG_RSHARE_USER=${rclone_user} \
-e RCLONE_CONFIG_RSHARE_PASS=${rclone_password}"
else
    env_options+="-e RCLONE_CONFIG=${rclone_conf_container}"
    if [ -f "$rclone_conf_host" ]; then
        mount_options+=" -v $(dirname ${rclone_conf_host}):$(dirname ${rclone_conf_container})"
    fi
fi

# Mount extra directories if defined
if [ ${#mount_extra_options} -ge 5 ]; then
    mount_options+=" ${mount_extra_options}"
fi

# Add app_in_out_base_dir if set
if [ ${#app_in_out_base_dir} -gt 5 ]; then
    env_options+=" -e APP_INPUT_OUTPUT_BASE_DIR=${app_in_out_base_dir}"
fi

# Add flaat env setting
env_options+=" -e DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER=$flaat_disable"

export UDOCKER_OPTIONS="${env_options} ${mount_options}"

### Configure SLURM submission
SLURM_OPTIONS="--partition=${slurm_partition} \
--nodes=${slurm_nodes} \
--ntasks-per-node=${slurm_tasks_per_node} \
--time=${slurm_time} \
--job-name=${UDOCKER_CONTAINER}"

# Check if slurm_log_dir exists
if [ ! -d "$slurm_log_dir" ]; then
    mkdir -p "$slurm_log_dir"
fi

# Default log file
slurm_log_file="${slurm_log_dir}/${DATENOW}-${UDOCKER_CONTAINER}.log"

echo "=== DATE: ${DATENOW}" >>${slurm_log_file}
echo "== DOCKER_IMAGE: ${DOCKER_IMAGE}" >>${slurm_log_file}
echo "== UDOCKER_CONTAINER: ${UDOCKER_CONTAINER}" >>${slurm_log_file}
echo "== UDOCKER_OPTIONS: ${UDOCKER_OPTIONS}" >>${slurm_log_file}
echo "== UDOCKER_RUN_COMMAND: ${UDOCKER_RUN_COMMAND}" >>${slurm_log_file}

#... UDOCKER_USE_GPU + slurm's --gres
export UDOCKER_USE_GPU=false
if [ $num_gpus -gt 0 ]; then
    export UDOCKER_USE_GPU=true
    SLURM_OPTIONS+=" --gres=gpu:${num_gpus}"
    echo "== [INFO] GPU usage is activated" >>${slurm_log_file}
fi

# Add job log, if slurm_log is true
if echo ${slurm_log}| grep -iqF "true"; then
    SLURM_OPTIONS+=" --output=${slurm_log_file}"
fi

echo "== SLURM OPTIONS: ${SLURM_OPTIONS}" >>${slurm_log_file}

# Final submission to SLURM
sbatch ${SLURM_OPTIONS} ${slurm_job2run}

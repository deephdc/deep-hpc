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
export DOCKER_IMAGE="deephdc/deep-oc-benchmarks_cnn:gpu"
export UDOCKER_CONTAINER="deep-oc-benchmarks-gpu"
export UDOCKER_RECREATE=False

##... SLURM CONFIG ...##
# For CPU: standard, For GPU: tesla
slurm_partition="tesla"
slurm_nodes=1
slurm_time="12:00:00"
slurm_tasks_per_node=8
slurm_jobname=${UDOCKER_CONTAINER}
slurm_log_dir="${HOME}/tmp/jobs"
slurm_joblog="${slurm_log_dir}/${DATENOW}-${slurm_jobname}.log"
slurm_job2run="${SCRIPT_PATH}/udocker_job.sh"
##

##... oneclient ..##
export ONECLIENT_ACCESS_TOKEN="MDXXX"
# options: 
# oprov.ifca.es 
# oneprovider.fedcloud.eu
# cloud-90-147-75-163.cloud.ba.infn.it
export ONECLIENT_PROVIDER_HOST="oprov.ifca.es"
export ONEDATA_MOUNT_POINT="$HOME/datasets"
##

mount_options="-v $HOME/deep-oc-apps/benchmarks_cnn:/mnt/benchmarks_cnn"
app_in_out_base_dir="/mnt/benchmarks_cnn"

num_gpus=2
flaat_disable="yes"

##... rclone config ...##
rclone_conf="/srv/.rclone/rclone.conf"
rclone_vendor="nextcloud"
rclone_type="webdav"
rclone_url="https://nc.deep-hybrid-datacloud.eu/remote.php/webdav/"
rclone_user="DEEP-XXX"
rclone_password="jXXX"
##

#... run_command configuration ...
export UDOCKER_RUN_COMMAND="deepaas-cli \
--deepaas_method_output=/mnt/benchmarks_cnn/${DATENOW}-train-out.txt \
train \
--batch_size_per_device=32 \
--num_epochs=0 \
--num_gpus=${num_gpus} \
--model=\"resnet50 (ImageNet)\" \
--dataset=\"Synthetic data\" \
--evaluation=true"
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
    -p|--partition \t Choose which cluster partition to use (e.g. CPU: 'standard', GPU: 'tesla')" 1>&2; exit 0;
    #-g|--gpus \t\t Number of GPUs to request
}

function check_arguments()
{
    OPTIONS=h,c:,g:,p:
    LONGOPTS=help,cmd:,gpus:,partition:
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
            -p|--partition)
                slurm_partition="$2"
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
###

### NEXT IS DERIVED FROM THE OPTIONS ABOVE
if [ ! -d ${slurm_log_dir} ]; then
    mkdir -p ${slurm_log_dir}
fi

echo "=== DATE: ${DATENOW}" >>${slurm_joblog}

### Configure UDOCKER_OPTIONS ###
env_options=""

if [ ${#rclone_user} -gt 8 ] && [ ${#rclone_password} -gt 8 ]; then
    env_options+="-e RCLONE_CONFIG=${rclone_conf} \
-e RCLONE_CONFIG_RSHARE_TYPE=${rclone_type} \
-e RCLONE_CONFIG_RSHARE_URL=${rclone_url} \
-e RCLONE_CONFIG_RSHARE_VENDOR=${rclone_vendor} \
-e RCLONE_CONFIG_RSHARE_USER=${rclone_user} \
-e RCLONE_CONFIG_RSHARE_PASS=${rclone_password}"
else
    env_options+="-e RCLONE_CONFIG=/srv/.rclone/rclone.conf"
fi

# add app_in_out_base_dir if set
if [ ${#app_in_out_base_dir} -gt 5 ]; then
    env_options+=" -e APP_INPUT_OUTPUT_BASE_DIR=${app_in_out_base_dir}"
fi

# add flaat env setting
env_options+=" -e DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER=$flaat_disable"

export UDOCKER_OPTIONS="${env_options} ${mount_options}"

### Configure SLURM submission
SLURM_OPTIONS="--partition=${slurm_partition} \
--nodes=${slurm_nodes} \
--ntasks-per-node=${slurm_tasks_per_node} \
--time=${slurm_time} \
--job-name=${slurm_jobname}"

#... UDOCKER_USE_GPU + slurm's --gres
export UDOCKER_USE_GPU=false
if [ $num_gpus -gt 0 ]; then
    export UDOCKER_USE_GPU=true
    SLURM_OPTIONS+=" --gres=gpu:${num_gpus}"
    echo "=== [INFO] GPU usage is activated" >>${slurm_joblog}
fi

# add job log, if the output file is provided (longer than 5 characters)
if [ ${#slurm_joblog} -ge 5  ]; then
    SLURM_OPTIONS+=" --output=${slurm_joblog}"
fi

echo "=== [SLURM settings]" >>${slurm_joblog}
echo " SLURM OPTIONS = ${SLURM_OPTIONS}" >>${slurm_joblog}
echo "=== [/SLURM] ===" >>${slurm_joblog}

# Final submission to SLURM
sbatch ${SLURM_OPTIONS} ${slurm_job2run}

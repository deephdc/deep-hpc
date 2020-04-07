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

### SLURM CONFIG ###
slurm_partition="standard"
slurm_nodes=1
slurm_time="12:00:00"
slurm_tasks_per_node=8
slurm_jobname="deep-app"
slurm_joblog=${DATENOW}-${slurm_jobname}-log.txt
slurm_job2run="${SCRIPT_PATH}/udocker_job.sh"
slurm_gres=""
###

### DEPLOYMENT MAIN CONFIGURATION (User Action!)
export DOCKER_IMAGE="deephdc/deep-oc-dogs_breed_det:cpu"
export UDOCKER_CONTAINER="deep-oc-dogs_breed-cpu"
export UDOCKER_RECREATE=false

MOUNT_OPTIONS="-v $HOME/deep-oc-apps/dogs_breed:/mnt/dogs_breed"

num_gpus=0

flaat_disable="yes"

#... rclone config ...
rclone_conf="/srv/.rclone/rclone.conf"
rclone_vendor="nextcloud"
rclone_type="webdav"
rclone_url="https://nc.deep-hybrid-datacloud.eu/remote.php/webdav/"
rclone_user="DEEP-XYXYYXYXYXYXYXYXYXY"
rclone_password="jXYXYXYXY_XYXYXYXYXY"

app_in_out_base_dir=${UCONTAINER_DIR}

#... run_command configuration ...
export UDOCKER_RUN_COMMAND="deepaas-cli \
--deepaas_method_output=/mnt/dogs_breed/${DATENOW}-train-out.txt \
train \
--num_epochs=5 \
--sys_info=True \
--network=Resnet50"

### END OF DEPLOYMENT MAIN CONFIG ###

### NEXT IS DERIVED FROM THE OPTIONS ABOVE
#... UDOCKER_USE_GPU ...
export UDOCKER_USE_GPU=false
if [ $num_gpus -gt 0 ]; then
    export UDOCKER_USE_GPU=true
    slurm_gres="--gres=gpu:${num_gpus}"
    echo "[INFO] GPU usage is activated"
fi

### Configure UDOCKER_OPTIONS ###
ENV_OPTIONS="-e RCLONE_CONFIG=${rclone_conf} \
-e RCLONE_CONFIG_RSHARE_TYPE=${rclone_type} \
-e RCLONE_CONFIG_RSHARE_URL=${rclone_url} \
-e RCLONE_CONFIG_RSHARE_VENDOR=${rclone_vendor} \
-e RCLONE_CONFIG_RSHARE_USER=${rclone_user} \
-e RCLONE_CONFIG_RSHARE_PASS=${rclone_password} \
-e APP_INPUT_OUTPUT_BASE_DIR=${app_in_out_base_dir}"

export UDOCKER_OPTIONS="${ENV_OPTIONS} ${MOUNT_OPTIONS}"

### Configure SLURM submission
SLURM_OPTIONS="--partition=${slurm_partition} \
--nodes=${slurm_nodes} \
--ntasks-per-node=${slurm_tasks_per_node} \
--time=${slurm_time} \
--job-name=${slurm_jobname} \
--output=${slurm_joblog} \
${slurm_gres}"

# Final submission to SLURM
sbatch ${SLURM_OPTIONS} ${slurm_job2run}

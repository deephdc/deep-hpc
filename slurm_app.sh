#!/bin/bash
#########################################
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
#########################################
DATENOW=$(date +%y%m%d_%H%M%S)

### SLURM CONFIG ###
SLURM_PARTITION="standard"
SLURM_NODES=1
SLURM_TIME="3:00:00"
SLURM_TASKS_PER_NODE=24
SLURM_JOBNAME="deep-app"
SLURM_JOBLOG=${DATENOW}-${SLURM_JOBNAME}-log.txt
SLURM_JOB2RUN="./udocker_job.sh"
###

### DEPLOYMENT MAIN CONFIGURATION (User Action!)
export DOCKER_IMAGE="deephdc/deep-oc-dogs_breed_det:cpu"
export UDOCKER_CONTAINER="deep-oc_dogs_breed"

HOST_DIR="$HOME/deep-oc-apps/dogs_breed"
UCONTAINER_DIR="/mnt/dogs_breed"

num_gpus=0

flaat_disable="yes"

rclone_conf="/srv/.rclone/rclone.conf"
rclone_vendor="nextcloud"
rclone_type="webdav"
rclone_url="https://nc.deep-hybrid-datacloud.eu/remote.php/webdav/"
rclone_user="DEEP-XYXYXYXYXXYXY"
rclone_password="jXYXYXYXYXXYXYXYXY"

app_in_out_base_dir=${UCONTAINER_DIR}

#... run_command configuration ...
export UDOCKER_RUN_COMMAND="deepaas-cli train \
--num_epochs=5 \
--sys_info=True \
--network=Resnet50"

### END OF DEPLOYMENT MAIN CONFIG ###

### NEXT IS DERIVED FROM THE OPTIONS ABOVE
### UDOCKER_USE_GPU ###
UDOCKER_USE_GPU=false
if [ $num_gpus -gt 0 ]; then
    export UDOCKER_USE_GPU=true
    echo "GPU usage is activated"
fi

### Configure UDOCKER_OPTIONS ###
ENV_OPTIONS="-e RCLONE_CONFIG=${rclone_conf} \
-e RCLONE_CONFIG_RSHARE_TYPE=${rclone_type} \
-e RCLONE_CONFIG_RSHARE_URL=${rclone_url} \
-e RCLONE_CONFIG_RSHARE_VENDOR=${rclone_vendor} \
-e RCLONE_CONFIG_RSHARE_USER=${rclone_user} \
-e RCLONE_CONFIG_RSHARE_PASS=${rclone_password} \
-e APP_INPUT_OUTPUT_BASE_DIR=${app_in_out_base_dir}"

MOUNT_OPTIONS="-v ${HOST_DIR}:${UCONTAINER_DIR}"

export UDOCKER_OPTIONS="${ENV_OPTIONS} ${MOUNT_OPTIONS}"

### Configure SLURM submission
sbatch --partition=${SLURM_PARTITION} \
--nodes=${SLURM_NODES} \
--ntasks-per-node=${SLURM_TASKS_PER_NODE} \
--time=${SLURM_TIME} \
--job-name=${SLURM_JOBNAME} \
--output=${SLURM_JOBLOG} \
${SLURM_JOB2RUN}

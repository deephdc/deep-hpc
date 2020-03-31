#!/bin/bash
#####################################
# Script to submit a job to slurm batch system
# 
# Parameters for SBATCH as defined in deepaas-hpc.sh
# --partition production
# --nodes=1
# --ntasks-per-node=24
# --time=3:00:00
# --job-name=deep-oc-app
#####################################
DATENOW=$(date +%y%m%d_%H%M%S)

export DOCKER_IMAGE="deephdc/deep-oc-dogs_breed_det:gpu"
export UDOCKER_CONTAINER="deep-oc_dogs_breed"

num_gpus=1

flaat_disable="yes"

rclone_conf="/srv/.rclone/rclone.conf"
rclone_vendor="nextcloud"
rclone_type="webdav"
rclone_url="https://nc.deep-hybrid-datacloud.eu/remote.php/webdav/"
rclone_user="DEEP-XYXYXYXYXXYXY"
rclone_password="jXYXYXYXYXXYXYXYXY"

HOST_DIR="$HOME/deep-oc-apps/dogs_breed"
UCONTAINER_DIR="/mnt/dogs_breed"

app_in_out_base_dir=${UCONTAINER_DIR}

### UDOCKER_USE_GPU ###
UDOCKER_USE_GPU=false
if [ $num_gpus -gt 0 ]; then
    UDOCKER_USE_GPU=true
fi

### Configure UDOCKER_OPTIONS ###
ENV_OPTIONS="-e RCLONE_CONFIG=${rclone_conf}
-e RCLONE_CONFIG_RSHARE_TYPE=${rclone_type} \
-e RCLONE_CONFIG_RSHARE_URL=${rclone_url} \
-e RCLONE_CONFIG_RSHARE_VENDOR=${rclone_vendor} \
-e RCLONE_CONFIG_RSHARE_USER=${rclone_user} \
-e RCLONE_CONFIG_RSHARE_PASS=${rclone_password} \
-e APP_INPUT_OUTPUT_BASE_DIR=${app_in_out_base_dir}"

MOUNT_OPTIONS="-v ${HOST_DIR}:${UCONTAINER_DIR}"

export UDOCKER_OPTIONS="${RCLONE_OPTIONS} $MOUNT_OPTIONS"

### RUN_COMMAND ###
export UDOCKER_RUN_COMMAND="deepaas-cli train \
--num_epochs=10 \
--sys_info=True \
--network=Resnet50"

### JOB LOG ###
JOBLOG=${DATENOW}-${UDOCKER_CONTAINER}-log.txt

echo "Submitting the app.."
#sbatch --output=$JOBLOG ./udocker_job.sh
./udocker_job.sh
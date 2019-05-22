#!/bin/bash
#
# This code is distributed under the MIT License
# Please, see the LICENSE file
# 2019 Damian Kaliszan, Valentin Kozlov

#SBATCH --partition normal
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=12
#SBATCH --time=3:00:00
#SBATCH --job-name=deep

### <<<= SET OF USER PARAMETERS =>>> ###
### Container configuration
DockerImage="deephdc/deep-oc-generic-dev:tf-py2" # deep-oc-generic-dev:tf-gpu-py2
ContainerName="deep-ddi-gpu-py2"  # deep-ddi-gpu-py2
USE_GPU=false                     # true
DEEPaaSPort=5000
JupyterPort=8888
MonitorPort=6006

### Matching between Host directories and Container ones
# Comment out if not used
#
# Name of the corresponding Python package
#HostData=$HOME/datasets/imagenet
#ContainerData=/srv/data
#
#HostModels=$HOME/datasets/models
#ContainerModels=/srv/models
###

### rclone settings
# rclone configuration is specified either in the rclone.conf file
# OR via environment settings
# we skip later environment settings if "HostRclone" is provided
# HostRclone = Host directory where rclone.conf is located at the host
rclone_config="/srv/.rclone/rclone.conf"
HostRclone=$HOME/.config/rclone
rclone_vendor="nextcloud"
rclone_type="webdav"
rclone_url="https://nc.deep-hybrid-datacloud.eu/remote.php/webdav/"
rclone_user="DEEP-XYXYXYXYXXYXY"
rclone_pass="jXYXYXYXYXXYXYXYXY"
### rclone

flaat_disable="no"

### <<<= END OF SET OF USER PARAMETERS =>>> ###


#udocker run -p $port:$port  deephdc/deep-oc-generic-container
IFExist=$(udocker ps |grep "${ContainerName}")
if [ ${#IFExist} -le 1 ]; then
    udocker pull ${DockerImage}
    echo Creating container ${ContainerName}
    udocker create --name=${ContainerName} ${DockerImage}
else
    echo "=== [INFO] ==="
    echo " ${ContainerName} already exists!"
    echo " Trying to re-use it..."
    echo "=== [INFO] ==="
fi

# if GPU is to be used, apply an 'nvidia hack'
# and setup the container for GPU
if [ "$USE_GPU" = true ]; then
    nvidia-modprobe -u -c=0
    udocker setup --nvidia --force ${ContainerName}
fi

MountOpts=""
if [ ! -z "$HostData" ] && [ ! -z "$ContainerData" ]; then
    MountOpts+=" -v ${HostData}:${ContainerData}"

    # check if local directories exist, create
    [[ ! -d "$HostData" ]] && mkdir -p $HostData
fi

if [ ! -z "$HostModels" ] && [ ! -z "$ContainerModels" ]; then
    MountOpts+=" -v ${HostModels}:${ContainerModels}"

    # check if local directories exist, create
    [[ ! -d "$HostModels" ]] && mkdir -p $HostModels
fi

if [ ! -z "$HostRclone" ] && [ ! -z "$rclone_config" ]; then
    rclone_dir=$(dirname "${rclone_config}")
    MountOpts+=" -v ${HostRclone}:${rclone_dir}"
fi

[[ "$debug_it" = true ]] && echo "MountOpts: "$MountOpts

EnvOpts=""

[[ ! -z "$rclone_config" ]] && EnvOpts+=" -e RCLONE_CONFIG=${rclone_config}"

# rclone configuration is specified either in the rclone.conf file
# OR via environment settings
# we skip environment settings if $HostRclone is provided
if [ -z "$HostRclone" ]; then
    [[ ! -z "$rclone_type" ]] && EnvOpts+=" -e RCLONE_CONFIG_RSHARE_TYPE=$rclone_type"
    [[ ! -z "$rclone_vendor" ]] && EnvOpts+=" -e RCLONE_CONFIG_RSHARE_VENDOR=$rclone_vendor"
    [[ ! -z "$rclone_url" ]] && EnvOpts+=" -e RCLONE_CONFIG_RSHARE_URL=$rclone_url"
    [[ ! -z "$rclone_user" ]] && EnvOpts+=" -e RCLONE_CONFIG_RSHARE_USER=$rclone_user"
    [[ ! -z "$rclone_pass" ]] && EnvOpts+=" -e RCLONE_CONFIG_RSHARE_PASS=$rclone_pass"
fi

if [ ! -z "$flaat_disable" ]; then
    EnvOpts+=" -e DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER=$flaat_disable"
fi

[[ "$debug_it" = true ]] && echo "EnvOpts: "$EnvOpts

UDOCKER_RUN_PARAMS="--hostauth --user=$USER \
-p ${DEEPaaSPort}:5000 \
-p ${JupyterPort}:8888 \
-p ${MonitorPort}:6006 \
${MountOpts} ${EnvOpts}"


echo "udocker run ${UDOCKER_RUN_PARAMS} ${ContainerName}"
udocker run ${UDOCKER_RUN_PARAMS} ${ContainerName}

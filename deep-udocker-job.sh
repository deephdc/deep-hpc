#!/bin/bash
#
# -*- coding: utf-8 -*-
#
# Copyright (c) 2018 - 2020 Karlsruhe Institute of Technology - Steinbuch Centre for Computing
# This code is distributed under the MIT License
# Please, see the LICENSE file
#
# @author: vykozlov
#

###  INFO  ###
# Script that runs a DEEP-OC application via a udocker container.
###

function print_date()
{
    echo $(date +'%Y-%m-%d %H:%M:%S')
}

function short_date()
{
    echo $(date +'%y%m%d_%H%M%S')
}


echo "=== DATE: $(print_date)"
echo "== DOCKER_IMAGE: ${DOCKER_IMAGE}"
echo "== UDOCKER_CONTAINER: ${UDOCKER_CONTAINER}"
## (!) Comment UDOCKER_OPTIONS, as this may publish AUTHENTICATION info:
echo "== UDOCKER MOUNT_OPTIONS: ${MOUNT_OPTIONS}"
echo "== (!) UDOCKER ENVIRONMENT OPTIONS are NOT PRINTED for security reasons! (!)"
echo "== UDOCKER_OPTIONS: ${UDOCKER_OPTIONS}"
echo "== UDOCKER_RUN_COMMAND: ${UDOCKER_RUN_COMMAND}"
echo "== SLURM_JOBID: ${SLURM_JOB_ID}"
echo "== SLURM_OPTIONS (partition : nodes : ntasks-per-node : time): \
$SLURM_JOB_PARTITION : $SLURM_JOB_NODELIST : $SLURM_NTASKS_PER_NODE :  $SBATCH_TIMELIMIT"
echo ""

##### CHECK for udocker and INSTALL if missing ######
export PATH="$HOME/udocker:$PATH"
echo "== [udocker check: $(print_date) ]"
if command udocker version 2>/dev/null; then
   echo "= udocker is present!"
else
   echo "= [WARNING: $(print_date) ]: udocker is NOT found. Trying to install..."
   [[ -d "$HOME/udocker" ]] && mv "$HOME/udocker" "$HOME/udocker-$(short_date).bckp"
   echo "= Downloading from $UDOCKER_DOWNLOAD_LINK"
   cd $HOME && wget $UDOCKER_DOWNLOAD_LINK
   udocker_tar="${UDOCKER_DOWNLOAD_LINK##*/}"
   tar zxvf "$udocker_tar"

   if command udocker version 2>/dev/null; then
       echo "= [INFO: $(print_date)] Now udocker is found!"
   else
       echo "[ERROR: $(print_date)] hmm... udocker is still NOT found! Exiting..."
       exit 1
   fi
fi
echo "== [/udocker check]"
echo ""

##### MOUNT ONEDATA on the HOST #####
if [ ${#ONECLIENT_ACCESS_TOKEN} -gt 8 ] && [ ${#ONECLIENT_PROVIDER_HOST} -gt 8 ]; then
   echo "== [ONEDATA: $(print_date) ]"
   echo "...ONECLIENT_PROVIDER_HOST = ${ONECLIENT_PROVIDER_HOST}"
   echo "...HOST_ONEDATA_MOUNT_POINT = ${HOST_ONEDATA_MOUNT_POINT}"
   oneclient --version

   # check if the local mount point exists
   if [ ! -d "${HOST_ONEDATA_MOUNT_POINT}" ]; then
       mkdir -p ${HOST_ONEDATA_MOUNT_POINT}
   fi
   oneclient ${HOST_ONEDATA_MOUNT_POINT}
   echo "...checking the content of ${HOST_ONEDATA_MOUNT_POINT}:"
   ls -la ${HOST_ONEDATA_MOUNT_POINT}
   echo "== [/ONEDATA]"
fi
####
echo ""

##### RUN THE JOB #####
IFContainerExists=$(udocker ps |grep "${UDOCKER_CONTAINER}")
IFImageExists=$(echo ${IFContainerExists} |grep "${DOCKER_IMAGE}")
if [ ${#IFImageExists} -le 1 ] || [ ${#IFContainerExists} -le 1 ] || echo ${UDOCKER_RECREATE} |grep -iqF "true"; then
    echo "== [INFO: $(print_date) ]"
    if [ ${#IFContainerExists} -gt 1 ]; then
        echo "= Removing container ${UDOCKER_CONTAINER}..."
        udocker rm ${UDOCKER_CONTAINER}
    fi
    udocker pull ${DOCKER_IMAGE}
    echo "= $(print_date): Creating container ${UDOCKER_CONTAINER}..."
    udocker create --name=${UDOCKER_CONTAINER} ${DOCKER_IMAGE}
    echo "= $(print_date): Created"
    echo "== [/INFO]"
else
    echo "== [INFO: $(print_date) ]"
    echo "= ${UDOCKER_CONTAINER} already exists!"
    echo "= udocker ps: ${IFContainerExists}"
    echo "= Trying to re-use it..."
    echo "== [/INFO]"
fi
echo ""

# if GPU is to be used, apply an 'nvidia hack'
# and setup the container for GPU
if echo ${UDOCKER_USE_GPU} |grep -iqF "true"; then
    echo "== [NVIDIA: $(print_date) ]"
    echo "=  Setting up Nvidia compatibility."
    nvidia-modprobe -u -c=0  # CURRENTLY only to circumvent a bug
    udocker setup --nvidia --force ${UDOCKER_CONTAINER}
    udocker run ${UDOCKER_CONTAINER} nvidia-smi
    echo "== [/NVIDIA]"
fi
echo ""

### current hack to install deepaas-cli
echo "== [DEEPaaS: $(print_date) ]"
udocker run ${UDOCKER_CONTAINER} /bin/bash <<EOF
if [ ! -f /usr/bin/deepaas-cli ] && [ ! -f /usr/local/bin/deepaas-cli ]; then
    [[ -d DEEPaaS ]] && rm -rf DEEPaaS
    git clone -b deep_cli https://github.com/indigo-dc/DEEPaaS
    pip install -e DEEPaaS
else
    echo "= deepaas-cli is found"
fi
echo -n "= " && type -a deepaas-cli
EOF
echo "== [/DEEPaaS]"
echo ""

echo "== [RUN: $(print_date) ] Running the application..."
udocker run ${UDOCKER_OPTIONS} ${UDOCKER_CONTAINER} /bin/bash <<EOF
${UDOCKER_RUN_COMMAND}
EOF

echo "==[/RUN]"
echo ""

echo "[ONEDATA] Unmount ${HOST_ONEDATA_MOUNT_POINT}"
oneclient -u ${HOST_ONEDATA_MOUNT_POINT}

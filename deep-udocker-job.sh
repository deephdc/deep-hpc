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

##### MOUNT ONEDATA on the HOST #####
if [ ${#ONECLIENT_ACCESS_TOKEN} -gt 8 ] && [ ${#ONECLIENT_PROVIDER_HOST} -gt 8 ]; then
   # check if the local mount point exists
   if [ ! -d "${ONEDATA_MOUNT_POINT}" ]; then
       mkdir -p ${ONEDATA_MOUNT_POINT}
   fi
   echo "== [ONEDATA: $(print_date) ]"
   echo "...ONECLIENT_PROVIDER_HOST = ${ONECLIENT_PROVIDER_HOST}"
   echo "...ONEDATA_MOUNT_POINT = ${ONEDATA_MOUNT_POINT}"
   oneclient --version
   oneclient ${ONEDATA_MOUNT_POINT}
   ls ${ONEDATA_MOUNT_POINT}
   echo "== [/ONEDATA]"
fi
####

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

echo "== [INFO: $(print_date) ]"
echo "= udocker container: ${UDOCKER_CONTAINER}"
echo "= Running on: $HOSTNAME"
echo "== [/INFO]"

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

echo "== [RUN: $(print_date) ] Running the application..."
udocker run ${UDOCKER_OPTIONS} ${UDOCKER_CONTAINER} /bin/bash <<EOF
${UDOCKER_RUN_COMMAND}
EOF

echo "==[/RUN]"

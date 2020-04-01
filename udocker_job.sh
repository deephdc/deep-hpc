#!/bin/bash
############################################################################
# Script that runs a DEEP-OC application via a udocker container.
#
# NOTE: The udocker container needs to be set up with nvidia compatibility
############################################################################


##### RUN THE JOB #####
IFContainerExists=$(udocker ps |grep "${UDOCKER_CONTAINER}")
IFImageExists=$(echo ${IFContainerExists} |grep "${DOCKER_IMAGE}")
if [ ${#IFImageExists} -le 1 ] || [ ${#IFContainerExists} -le 1 ] || [ "$UDOCKER_RECREATE" = true ]; then
    udocker pull ${DOCKER_IMAGE}
    echo Creating container ${UDOCKER_CONTAINER}
    udocker create --name=${UDOCKER_CONTAINER} ${DOCKER_IMAGE}
else
    echo "=== [INFO] ==="
    echo " ${UDOCKER_CONTAINER} already exists!"
    echo " udocker ps: ${IFContainerExists}"
    echo " Trying to re-use it..."
    echo "=== [INFO] ==="
fi

# if GPU is to be used, apply an 'nvidia hack'
# and setup the container for GPU
if [ "$UDOCKER_USE_GPU" = true ]; then
    echo "Setting up Nvidia compatibility."
    #nvidia-modprobe -u -c=0  # CURRENTLY only to circumvent a bug
    udocker setup --nvidia --force ${UDOCKER_CONTAINER}
    nvidia-smi
fi

echo "==================================="
echo "=> udocker container: ${UDOCKER_CONTAINER}"
echo "=> Running on: $HOSTNAME"
echo "...UDOCKER_OPTIONS = ${UDOCKER_OPTIONS}"
echo "...UDOCKER_RUN_COMMAND = ${UDOCKER_RUN_COMMAND}"
echo "==================================="

### current hack to install deepaas-cli
udocker run ${UDOCKER_CONTAINER} git clone -b deep_cli https://github.com/indigo-dc/DEEPaaS
udocker run ${UDOCKER_CONTAINER} pip install -e /srv/DEEPaaS

echo "Running the application..."
udocker run ${UDOCKER_OPTIONS} ${UDOCKER_CONTAINER} ${UDOCKER_RUN_COMMAND}

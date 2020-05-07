#!/bin/bash
#
# Copyright (c) 2017 - 2019 Karlsruhe Institute of Technology - Steinbuch Centre for Computing
# This code is distributed under the MIT License
# Please, see the LICENSE file
#

topology_file="qcg-job.yaml"

USAGEMESSAGE="[Usage]: $0 [topology yaml file, default=$topology_file]"

DATENOW=$(date +'%y%m%d_%H%M%S')

if [[ $1 == "-h" ]] || [[ $1 == "--help" ]]; then
    shopt -s xpg_echo
    echo $USAGEMESSAGE
    exit 1
elif [ $# -eq 1 ]; then
    topology_file=$1
fi

# let's download tosca template automatically, if not found:
if [ ! -f $topology_file ]; then
    curl -o $topology_file \
    https://raw.githubusercontent.com/deephdc/deep-hpc/qcg/$topology_file
fi

### EXAMPLES FOR SOME PARAMETERS
# "run_command": "deepaas-cli train --num_epochs=15",
# "run_command": "/srv/.deep-start/run_jupyter.sh --allow-root",
# "jupyter_password": "xxxxxxxx"
###

### MAIN CALL FOR THE DEPLOYMENT
#   DEFINE PARAMETERS OF YOUR DEPLOYMENT HERE
#
export ORCHENT_URL=https://deep-paas-dev.cloud.ba.infn.it/orchestrator
orchent depcreate $topology_file '{ "docker_image": "deephdc/deep-oc-dogs_breed_det:cpu",
                                    "run_command": "deepaas-cli train --num_epochs=15",
                                    "recreate_container": "true",
                                    "delete_after": "true",
                                    "udocker_extra_options": "",
                                    "onedata_space_name": "datahpc",
                                    "onedata_mount_point": "/mnt/onedata",
                                    "rclone_conf_host": "$HOME/.config/rclone/rclone.conf",
                                    "rclone_conf_container": "/srv/.rclone/rclone.conf",
                                    "app_in_out_base_dir": "/mnt/onedata/datahpc/dogs_breed",
                                    "num_gpus": "0",
                                    "total_cores": "2",
                                    "queue": "standard",
                                    "std_outerr": "log-dogs-train.txt" }'

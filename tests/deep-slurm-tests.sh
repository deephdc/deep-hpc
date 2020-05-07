#!/bin/bash
#
# -*- coding: utf-8 -*-
#
# Copyright (c) 2018 - 2020 Karlsruhe Institute of Technology - Steinbuch Centre for Computing
# This code is distributed under the MIT License
# Please, see the LICENSE file
#
# @author: vykozlov

### INFO
# simple tests of various possibilities
# of calling deep-slurm-app.sh
#

SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"

echo "[TEST: Default settings (CPU)]"
../deep-slurm-app
echo
sleep 2

echo "[TEST: Re-define with command line options: slurm partition, slurm logging, number of gpus (GPU)]"
../deep-slurm-app -p tesla -l -g 1
echo
sleep 2

echo "[TEST: Use another INI file, other docker image, trigger container recreation, slurm logging, cmd (CPU)]"
# N.B.: Escaping \$ in front of the variable does not expand it but allows to use its variable name
../deep-slurm-app -i deep-slurm-tests.ini -d deephdc/deep-oc-dogs_breed_det:cpu -r -l \
-c "deepaas-cli --deepaas_method_output=\${HOST_DIR_MOUNT_POINT}/get_metadata.out get_metadata"
echo
sleep 2

echo "[TEST: Use another INI file, re-define slurm partition, slurm logging, \
re-define host_base_dir (-v), what command to run inside the container (CPU)]"
# N.B.: Escaping \$ in front of the variable does not expand it but allows to use its variable name
host_dir=$HOME/tmp/dogs_breed
[[ ! -d $host_dir ]] && mkdir -p $host_dir
cp St_Bernard_wiki_3.jpg $host_dir
cd ..
./deep-slurm-app -p tesla -l -i tests/deep-slurm-tests.ini -v "$host_dir" \
-c "deepaas-cli predict --files=\${HOST_DIR_MOUNT_POINT}/St_Bernard_wiki_3.jpg"

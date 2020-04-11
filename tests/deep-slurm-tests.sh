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
../deep-slurm-app.sh
echo
sleep 2

echo "[TEST: Command line options: partition, gpus, log (GPU)]"
../deep-slurm-app.sh -p tesla -g 1 -l
echo
sleep 2

echo "[TEST: Use another docker image, cli options: docker, recreate, log, cmd (CPU)]"
../deep-slurm-app.sh -l -r -d deephdc/deep-oc-dogs_breed_det:cpu-test -c "deepaas-cli get_metadata"
echo
sleep 2

echo "[TEST: Use another INI file, cmd, re-define host_base_dir (-v) (GPU)]"
# Reminder: by default HOST_BASE_DIR is mounted at APP_IN_OUT_BASE_DIR in the container
# N.B.: Escaping \$ in front of the variable does not expand it but transfers as variable name
host_base_dir=$HOME/tmp/dogs_breed
[[ ! -d $host_base_dir ]] && mkdir -p $host_base_dir
cp St_Bernard_wiki_3.jpg $host_base_dir
cd ..
./deep-slurm-app.sh -p tesla -g 1 -l -i tests/deep-slurm-tests.ini -v "$host_base_dir" \
-c "deepaas-cli predict --files=\${APP_IN_OUT_BASE_DIR}/St_Bernard_wiki_3.jpg"


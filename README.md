DEEP-HPC
=========

A set of bash scripts to submit a [DEEPaaS API](https://github.com/indigo-dc/DEEPaaS) based docker image (e.g. those listed in the [DEEP Open Catalog](https://marketplace.deep-hybrid-datacloud.eu/)) to an HPC batch system (slurm).

* deepaas-hpc.sh  - main script to define which docker image to use, what local directories to use (if needed), rclone settings for accessing a remote storage, if GPU access needs to be configured
* slurm_job.sh   - an example scipt for the SLURM based batch system

2019 Damian Kaliszan, Valentin Kozlov

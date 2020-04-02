deep-hpc
=========

A set of bash scripts to submit a [DEEPaaS API](https://github.com/indigo-dc/DEEPaaS) based docker image (e.g. those listed in the [DEEP Open Catalog](https://marketplace.deep-hybrid-datacloud.eu/)) to an HPC batch system (slurm).

It relies on [udocker tool](https://github.com/indigo-dc/udocker) for unprivileged containers.

* ``slurm_app.sh``   - main script to configure job submission for your application. Inside the script one defines:
   - ``slurm_`` : SLURM job parameters
   - ``DOCKER_IMAGE`` : which docker image to use
   - ``UDOCKER_CONTAINER`` : how to name the container to be used with udocker
   - ``UDOCKER_RECREATE`` : if true, enforce creating container, even it already exists
   - ``HOST_DIR`` : what host directory to mount inside the container
   - ``UCONTAINER_DIR`` : mount point inside the container for HOST_DIR
   - ``num_gpus`` : number of GPUs to be used on one node
   - ``flaat_disable`` : if true, it disables [flaat](https://github.com/indigo-dc/flaat) authentication
   - ``rclone_`` : parameters to configure the [rclone]() tool for copying remote data (webdav)
   - ``app_in_out_base_dir`` : base directory for input and output data (e.g. training data, models)
   - ``UDOCKER_RUN_COMMAND`` : configure the command to run inside the container
   
   internally the script exports ``DOCKER_IMAGE``, ``UDOCKER_CONTAINER``, ``UDOCKER_RECREATE``, ``UDOCKER_USE_GPU``, ``UDOCKER_OPTIONS``, ``UDOCKER_RUN_COMMAND`` to use inside ``udocker_job.sh``
   
* ``udocker_job.sh`` : script to pull a Docker image, configure udocker container and run a command inside the container. In general, it does not need changes by a user.

2019 Damian Kaliszan, Valentin Kozlov

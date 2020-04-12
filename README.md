deep-hpc
=========

A set of bash scripts to submit a [DEEPaaS API](https://github.com/indigo-dc/DEEPaaS) based docker image (e.g. those listed in the [DEEP Open Catalog](https://marketplace.deep-hybrid-datacloud.eu/)) to an HPC batch system (slurm).

It relies on the [udocker tool](https://github.com/indigo-dc/udocker) for unprivileged containers.

* ``deep-slurm-app.ini`` - main inizialization file to configure job submission for your application.
   - ``slurm_partition`` : which partition to use. Default is 'standard' (for CPU jobs). If you need to use GPU, set to 'tesla' (PSNC)
   - ``slurm_nodes`` : number of nodes requested for the job (default=1)
   - ``slurm_time`` : limit on the total run time of the job allocation (default 12 hours, 12:00:00)
   - ``slurm_tasks_per_node`` : number of tasks to be initiated on each node (default 8)
   - ``slurm_log`` : if true, the batch script's standard output is directed to the file (default false)
   - ``slurm_extra_options`` : any other SLURM option to activate. For more info, please, check [sbatch](https://slurm.schedmd.com/sbatch.html)
   - ``docker_image`` : which docker image to use.
   - ``udocker_recreate`` : if true, enforce creating container, even if it already exists.
   - ``udocker_container`` : OPTIONAL! It is interannly derived from DOCKER_IMAGE, but one can re-define it by providing the value here. If empty, ``udocker_container`` is defined by removing the repository name and "deep-oc-" if present, and adding the tag into the name. For example: ``docker_image=deephdc/deep-oc-dogs_breed_det:gpu`` becomes ``udocker_container=dogs_breed_det-gpu``
   - ``num_gpus`` : number of GPUs to be used on one node.
   - ``flaat_disable`` : if true, it disables [flaat](https://github.com/indigo-dc/flaat) authentication.
   - ``oneclient_access_token`` : ACCESS TOKEN for oneclient (not tested yet!)
   - ``oneclient_provider_host`` : which ONEDATA provider to connect to. (not tested yet!)
   - ``onedata_mount_point`` : in what directory to mount the onedata space (not tested yet!)
   - ``host_base_dir`` : directory on the host, where e.g. ~/data and ~/models directories are located. If empty, automatically assigned to $HOME/deep-oc-apps/$UDOCKER_CONTAINER.
   - ``app_in_out_base_dir`` : OPTIONAL! It is internally set to /mnt/$UDOCKER_CONTAINER but one can re-define it by providing the value here. Base directory for input and output data (e.g. training data, models) **inside the container**.
   - ``mount_extra_options`` : One may provide more options for mounting inside the container (Docker syntax, e.g. "-v /tmp:/tmp" to mount host /tmp at /tmp inside the container.
   - ``rclone_conf_host`` : location of rclone.conf file on the host (default $HOME/.config/rclone/rclone.conf). If provided, the rest rclone settings (see below) are ignored.
   - ``rclone_conf_container`` : where rclone.conf is expected inside the container (default /srv/.rclone/rclone.conf)
   - ``rclone_conf_vendor`` : rclone vendor (e.g. nextcloud)
   - ``rclone_conf_type`` : remote storage type (e.g. webdav)
   - ``rclone_conf_url`` : remote storage link to be accessed via rclone.
   - ``rclone_conf_user`` : rclone user to access a remote storage.
   - ``rclone_conf_password`` : rclone password to access a remote storage.
   - ``udocker_run_command`` : configure the command to run inside the container.

* ``deep-slurm-app.sh``   - script that configure the job submission (slurm). A user should not really change it. It reads ``deep-slurm-app.ini`` for default settings but some options can be re-defined from the command line:

```
    -h|--help      This help message
    -c|--cmd       Command to run inside the Docker image (overwrites ``UDOCKER_RUN_COMMAND``)
    -d|--docker    Docker image to run (overwrites ``DOCKER_IMAGE``)
    -g|--gpus      Number of GPUs to request (overwrites ``NUM_GPUS``)
    -i|--ini       INI file to load for the default settings (full path!)(default is deep-slurm-app.ini)
    -l|--log       If provided, activates SLURM output to the file (see ${slurm_log_dir} directory) (overwrites ``SLURM_LOG``)
    -p|--partition Choose which cluster partition to use (e.g. CPU: 'standard', GPU: 'tesla') (overwrites ``SLURM_PARTITION``)
    -r|--recreate  If provided, it forces re-creation of the container (overwrites ``UDOCKER_RECREATE``)
    -v|--volume    Host volume (directory), with e.g. ~/data and ~/models, to be mounted inside the container (overwrites ``HOST_BASE_DIR``)
```
   
* ``deep-udocker-job.sh`` : script to pull a Docker image, configure udocker container and run a command inside the container. In general, it does not need changes by a user.

## Usage examples

Following examples are also available in ``tests/deep-slurm-tests.sh``:

* Default settings (eveything is set in ``deep-slurm-app.ini``):
```
deep-slurm-app.sh
```
* Read default settings from ``deep-slurm-app.ini`` but re-define slurm partition, number of gpus, and slurm logging from the command line:
```
deep-slurm-app.sh -p tesla -l -g 1
```
* Read settings from another INI file, use other docker image, trigger recreation of the container, slurm logging, re-define which command to run inside the container:
```
deep-slurm-app.sh -i deep-slurm-tests.ini -d deephdc/deep-oc-dogs_breed_det:cpu-test -r -l -c "deepaas-cli get_metadata"
```
* Use another INI file, re-define slurm partition, slurm logging, number of GPUs, re-define host_base_dir (-v), which command to run inside the container (first copy St_Bernard_wiki_3.jpg to $HOME/tmp/dogs_breed (!)):
```
deep-slurm-app.sh -p tesla -l -g 1 -i tests/deep-slurm-tests.ini -v "$HOME/tmp/dogs_breed" \
-c "deepaas-cli predict --files=\${APP_IN_OUT_BASE_DIR}/St_Bernard_wiki_3.jpg"
```

2019 Damian Kaliszan, Valentin Kozlov

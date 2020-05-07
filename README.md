deep-hpc
=========

A set of bash scripts to submit a [DEEPaaS API](https://github.com/indigo-dc/DEEPaaS) based docker image (e.g. those listed in the [DEEP Open Catalog](https://marketplace.deep-hybrid-datacloud.eu/)) to an HPC batch system (slurm).

It relies on the [udocker tool](https://github.com/indigo-dc/udocker) for unprivileged containers.

* ``deep-slurm-app.ini`` - main inizialization file to configure job submission for your application.
   - ``SLURM_PARTITION`` : which partition to use. Default is 'standard' (for CPU jobs). If you need to use GPU, set to 'tesla' (PSNC)
   - ``SLURM_NODES`` : number of nodes requested for the job (default=1)
   - ``SLURM_TASKS_PER_NODE`` : number of tasks to be initiated on each node (default 8)
   - ``SLURM_LOG`` : if true, the batch script's standard output is directed to the file (default false)
   - ``SLURM_EXTRA_OPTIONS`` : any other SLURM option to activate, e.g. "--time=12:00:00" would limit execution time to 12 hours. For more info, please, check [sbatch](https://slurm.schedmd.com/sbatch.html)
   - ``DOCKER_IMAGE`` : which docker image to use.
   - ``UDOCKER_CONTAINER`` : OPTIONAL! It is internaly derived from DOCKER_IMAGE, but one can re-define it by providing the value here. If empty, ``UDOCKER_CONTAINER`` is defined by removing the repository name and "deep-oc-" if present, and adding the tag into the name. For example: ``docker_image=deephdc/deep-oc-dogs_breed_det:gpu`` becomes ``udocker_container=dogs_breed_det-gpu``
   - ``UDOCKER_RECREATE`` : if true, enforce creating container, even if it already exists.
   - ``UDOCKER_DELETE_AFTER`` : delete the container when job has finished (true) or keep (false).
   - ``NUM_GPUS`` : number of GPUs to be used on one node.
   - ``FLAAT_DISABLE`` : if true, it disables [flaat](https://github.com/indigo-dc/flaat) authentication.
   - ``ONECLIENT_ACCESS_TOKEN`` : ACCESS TOKEN for oneclient.
   - ``ONECLIENT_PROVIDER_HOST`` : which ONEDATA provider to connect to.
   - ``ONEDATA_MOUNT_POINT`` : in what directory to mount the onedata space **inside the container** (default /mnt/onedata)
   - ``HOST_DIR`` : directory on the host, where e.g. ~/data and ~/models directories are located.
   - ``HOST_DIR_MOUNT_POINT`` : where to mount $HOST_DIR *inside the container* (default /mnt/host).
   - ``UDOCKER_EXTRA_OPTIONS`` : One may provide more options for udocker, e.g. to mount other directories (udocker syntax, e.g. "-v /tmp:/tmp" to mount host /tmp at /tmp inside the container).
   - ``APP_IN_OUT_BASE_DIR`` : Base directory for input and output data (e.g. training data, models) **inside the container**.
   - ``RCLONE_CONF_HOST`` : location of rclone.conf file on the host (default $HOME/.config/rclone/rclone.conf). If provided, the rest rclone settings (see below) are ignored.
   - ``RCLONE_CONF_CONTAINER`` : where rclone.conf is expected inside the container (default /srv/.rclone/rclone.conf).
   - ``RCLONE_VENDOR`` : rclone vendor (e.g. nextcloud)
   - ``RCLONE_TYPE`` : remote storage type (e.g. webdav)
   - ``RCLONE_URL`` : remote storage link to be accessed via rclone.
   - ``RCLONE_USER`` : rclone user to access a remote storage.
   - ``RCLONE_PASSWORD`` : rclone password to access a remote storage.
   - ``jupyterPASSWORD`` : set password for JupyterNotebook or JupyterLab (if installed inside container).
   - ``UDOCKER_RUN_COMMAND`` : configure the command to run inside the container.

* ``deep-slurm-app.sh``   - script that configure the job submission (slurm). A user should not really change it. It reads ``deep-slurm-app.ini`` for default settings but some options can be re-defined from the command line:

```
    Options:
    -h|--help 		 This help message
    -b|--base-dir 	 Base directory *inside container* for input and output data (e.g. data, models)(APP_IN_OUT_BASE_DIR)
    -c|--cmd 		 Command to run inside the Docker image (UDOCKER_RUN_COMMAND)
    -d|--docker 	 Docker image to run  (DOCKER_IMAGE)
    -g|--gpus 		 Number of GPUs to request (NUM_GPUS)
    -i|--ini 		 INI file to load for the default settings (full path!)
    -l|--log 		 If provided, activates SLURM output to the file (see  directory)
    -p|--partition 	 Choose which cluster partition to use (e.g. CPU: 'standard', GPU: 'tesla') (SLURM_PARTITION)
    -r|--recreate 	 If provided, it forces re-creation of the container (UDOCKER_RECREATE)
    -v|--volume 	 Host volume (directory), with e.g. ~/data and ~/models, to be mounted inside the container (HOST_DIR)
```
   
* ``deep-udocker-job.sh`` : script to pull a Docker image, configure udocker container and run a command inside the container. In general, it does not need changes by a user.

* ``deep-slurm-qcg.sh``  - script for the integration with [QCG](http://www.qoscosgrid.org/trac/qcg-computing) system of PSNC cluster.



## Usage examples

Following examples are also available in ``tests/deep-slurm-tests.sh``:

* Default settings (eveything is set in ``deep-slurm-app.ini``):
```
deep-slurm-app
```
* Read default settings from ``deep-slurm-app.ini`` but re-define slurm partition, number of gpus, and slurm logging from the command line:
```
deep-slurm-app -p tesla -l -g 1
```
* Read settings from another INI file, use other docker image, trigger recreation of the container, slurm logging, re-define which command to run inside the container:
```
deep-slurm-app -i deep-slurm-tests.ini -d deephdc/deep-oc-dogs_breed_det:cpu -r -l \
-c "deepaas-cli get_metadata"
```
* Use another INI file, re-define slurm partition, slurm logging, number of GPUs, re-define host_base_dir (-v), which command to run inside the container (first copy St_Bernard_wiki_3.jpg to $HOME/tmp/dogs_breed (!)):
```
deep-slurm-app -p tesla -l -g 1 -i tests/deep-slurm-tests.ini -v "$HOME/tmp/dogs_breed" \
-c "deepaas-cli predict --files=/mnt/host/St_Bernard_wiki_3.jpg"
```

2019-2020 Damian Kaliszan, Valentin Kozlov

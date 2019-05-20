#!/usr/bin/env bash
#
# This code is distributed under the MIT License
# Please, see the LICENSE file
# 2019 Damian Kaliszan, Valentin Kozlov

#SBATCH --partition production
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --time=2:00:00
#SBATCH --job-name=deep

### <<<= SET OF USER PARAMETERS =>>> ###
# Docker image to download and use
DockerImage="deephdc/deep-oc-dogs_breed_det"
# Name for the container to be created (can be arbitrary name)
ContainerName="dogs-cpu"
USE_GPU=false

### Matching between Host directories and Container ones
# Comment out if not used
#
# Name of the corresponding Python package
PyPackage="dogs_breed_det"
HostData=$HOME/$PyPackage/data
ContainerData=/srv/$PyPackage/data
#
HostModels=$HOME/$PyPackage/models
ContainerModels=/srv/$PyPackage/models
###


### rclone settings
# rclone configuration is specified either in the rclone.conf file
# OR via environment settings
# we skip later environment settings if "HostRclone" is provided
# HostRclone = Host directory where rclone.conf is located at the host
rclone_config="/srv/.rclone/rclone.conf"
HostRclone=$HOME/.config/rclone
rclone_vendor="nextcloud"
rclone_type="webdav"
rclone_url="https://nc.deep-hybrid-datacloud.eu/remote.php/webdav/"
rclone_user="DEEP-XYXYXYXYXXYXY"
rclone_pass="jXYXYXYXYXXYXYXYXY"
### rclone

flaat_disable="yes"

### <<<= END OF SET OF USER PARAMETERS =>>> ###


### <<<= MAIN SCRIPT: =>>> ###
# DEFAULT IP:PORT FOR DEEPaaS API
deepaas_host=127.0.0.1
port=5000

debug_it=false

train_args=""
predict_arg=""
output=""
SCRIPT_PID=$$

function usage()
{
    echo "Usage: $0 \
    [-h|--help] [-t|--training Training arguments] \
    [-d|--predict File name used for prediction] \
    [-o|--output File to store output]" 1>&2; exit 0; 
}

function check_arguments()
{

    OPTIONS=h,t:,d:,o:
    LONGOPTS=help,training:,predict:
    # https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
    #set -o errexit -o pipefail -o noclobber -o nounset
    set  +o nounset
    ! getopt --test > /dev/null
    if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
        echo '`getopt --test` failed in this environment.'
        exit 1
    fi

    # -use ! and PIPESTATUS to get exit code with errexit set
    # -temporarily store output to be able to check for errors
    # -activate quoting/enhanced mode (e.g. by writing out “--options”)
    # -pass arguments only via   -- "$@"   to separate them correctly
    ! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        # e.g. return value is 1
        #  then getopt has complained about wrong arguments to stdout
        exit 2
    fi
    # read getopt’s output this way to handle the quoting right:
    eval set -- "$PARSED"

    if [ "$1" == "--" ]; then
        echo "[INFO] No arguments provided. DEEPaaS URL is set to http://${deepaas_host}:${port}/models. Exiting."
        exit 1
    fi
    # now enjoy the options in order and nicely split until we see --
    while true; do
        case "$1" in
            -h|--help)
                usage
                shift
                ;;
            -t|--training)
                train_args="$2"
                shift 2
                ;;
            -d|--predict)
                predict_arg="$2"
                shift 2
                ;;
            -o|--output)
                output="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                break
                ;;
        esac
    done

    [[ "$debug_it" = true ]] && echo "train_args: '$train_args', predict_arg: '$predict_arg', output: '$output'"
}

function get_node()
{
    if [ -z "${SLURM_JOB_NODELIST}" ]; then
        return
    fi
    IFS="," read -a sjl <<< "${SLURM_JOB_NODELIST}"
    node=${sjl[0]}
    echo $node
}

function is_deepaas_up()
{   #curl -X GET "http://127.0.0.1:5000/models/" -H  "accept: application/json"

    if [ -z "$1" ]; then
       max_try=11
    else
       max_try=$1
    fi

    running=false

    c_url="http://${deepaas_host}:${port}/models/"
    c_args_h1="Accept: application/json"

    itry=1

    while [ "$running" == false ] && [ $itry -lt $max_try ];
    do
       curl_call=$(curl -s -X GET $c_url -H "$c_args_h1")
       if (echo $curl_call | grep -q 'id\":') then
           echo "[INFO] Service is responding"
           running=true
       else
           echo "[INFO] Service is NOT (yet) responding. Try #"$itry
           sleep 10
           let itry=itry+1
       fi
    done

    return 0
}

function get_model_id()
{
    # curl -X GET "http://127.0.0.1:5000/models/" -H  "accept: application/json"
    #
    # - have to skip jq since it is not everywhere installed
    # - also some deepaas-based apps produce curl response in one string
    #   have to parse this string
    # Old version:
    # model_id=$(curl -s -X GET $c_url -H "$c_args_h1" | grep 'id\":' \
    #                                                  | awk '{print $2}' \
    #                                                  | cut -d'"' -f2)

    c_url="http://${deepaas_host}:${port}/models/"
    c_args_h1="Accept: application/json"

    curl_call=($(curl -s -X GET $c_url -H "$c_args_h1"))

    found=false
    counter=0
    while [ "$found" == false ] && [ $counter -lt ${#curl_call[@]} ];
    do
        if [[ "${curl_call[counter]}" == "\"id\":" ]]; then
           let ielem=counter+1
           model_id=${curl_call[ielem]}
           found=true
        fi
        let counter=counter+1
    done

    model_id=$(echo $model_id | cut -d'"' -f2)

    if [ -z "$model_id" ]; then
        echo "Unknown"
    else
        echo $model_id
    fi
}

function start_service()
{
    #udocker run -p $port:$port  deephdc/deep-oc-generic-container &

    IFExist=$(udocker ps |grep "${ContainerName}")
    if [ ${#IFExist} -le 1 ]; then
        udocker pull ${DockerImage}
        echo Creating container ${ContainerName}
        udocker create --name=${ContainerName} ${DockerImage}
    else
        echo "=== [INFO] ==="
        echo " ${ContainerName} already exists!"
        echo " Trying to re-use it..."
        echo "=== [INFO] ==="
    fi
    # if GPU is to be used, apply an 'nvidia hack'
    # and setup the container for GPU
    if [ "$USE_GPU" = true ]; then
       nvidia-modprobe -u -c=0
       udocker setup --nvidia ${ContainerName}
    fi

    MountOpts=""

    if [ ! -z "$HostData" ] && [ ! -z "$ContainerData" ]; then
        MountOpts+=" -v ${HostData}:${ContainerData}"

        # check if local directories exist, create
        [[ ! -d "$HostData" ]] && mkdir -p $HostData
    fi
    if [ ! -z "$HostModels" ] && [ ! -z "$ContainerModels" ]; then
        MountOpts+=" -v ${HostModels}:${ContainerModels}"

        # check if local directories exist, create
        [[ ! -d "$HostModels" ]] && mkdir -p $HostModels
    fi
    if [ ! -z "$HostRclone" ] && [ ! -z "$rclone_config" ]; then
        rclone_dir=$(dirname "${rclone_config}")
        MountOpts+=" -v ${HostRclone}:${rclone_dir}"
    fi
    [[ "$debug_it" = true ]] && echo "MountOpts: "$MountOpts

    EnvOpts=""

    [[ ! -z "$rclone_config" ]] && EnvOpts+=" -e RCLONE_CONFIG=${rclone_config}"

    # rclone configuration is specified either in the rclone.conf file
    # OR via environment settings
    # we skip environment settings if $HostRclone is provided
    if [ -z "$HostRclone" ]; then
        [[ ! -z "$rclone_type" ]] && EnvOpts+=" -e RCLONE_CONFIG_RSHARE_TYPE=$rclone_type"
        [[ ! -z "$rclone_vendor" ]] && EnvOpts+=" -e RCLONE_CONFIG_RSHARE_VENDOR=$rclone_vendor"
        [[ ! -z "$rclone_url" ]] && EnvOpts+=" -e RCLONE_CONFIG_RSHARE_URL=$rclone_url"
        [[ ! -z "$rclone_user" ]] && EnvOpts+=" -e RCLONE_CONFIG_RSHARE_USER=$rclone_user"
        [[ ! -z "$rclone_pass" ]] && EnvOpts+=" -e RCLONE_CONFIG_RSHARE_PASS=$rclone_pass"
    fi

    if [ ! -z "$flaat_disable" ]; then
       EnvOpts+=" -e DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER=$flaat_disable"
    fi

    [[ "$debug_it" = true ]] && echo "EnvOpts: "$EnvOpts

    (udocker run -p ${port}:5000 ${MountOpts} ${EnvOpts} \
                    ${ContainerName} deepaas-run --listen-ip=0.0.0.0) &
}


function train()
{
    # curl -X PUT "http://localhost:5000/models/Dogs_Breed/train?${train_args}"
    if [ -z "$1" ] || [ -z "$2" ]; then
        return 1
    fi
    echo ${deepaas_host}  ${port}
    model_id=$1
    train_args=$2
    echo "Model_id: ${model_id}, train_args: ${train_args}"
    c_url="http://${deepaas_host}:${port}/models/${model_id}/train?${train_args}"
    c_args_h1="accept: application/json"
    [[ ! -z $output ]] && c_out="-o $output" || c_out=""

    [[ "$debug_it" = true ]] &&echo curl $c_out -X PUT $c_url -H "$c_args_h1"
    
    curl_call=$(curl $c_out -X PUT $c_url -H "$c_args_h1")
    if [ -z "$curl_call" ]; then
        echo ""
    else
        echo "[INFO] TRAINING OUTPUT:"
        echo $curl_call
    fi
}

function predict()
{
    # curl -X POST "http://localhost:5000/models/Dogs_Breed/predict"
    # -H "accept: application/json" -H  "Content-Type: multipart/form-data"
    # -F "data=@St_Bernard_wiki_2.jpg;type=image/jpeg"

    if [ -z "$1" ] || [ -z "$2" ]; then
        return 1
    fi
    model_id=$1
    predict_file_name=$2

    c_url="http://${deepaas_host}:${port}/models/${model_id}/predict"
    c_args_h1="accept: application/json"
    c_args_h2="Content-Type: multipart/form-data"
    c_args_f1="data=@${predict_file_name};type=image/jpeg"
    [[ ! -z $output ]] && c_out="-o $output" || c_out=""

    [[ "$debug_it" = true ]] && echo curl -X POST $c_url $c_out -H "$c_args_h1" -H "$c_args_h2" -F "$c_args_f1"
    
    curl_call=$(curl $c_out -X POST $c_url -H "$c_args_h1" -H "$c_args_h2" -F "$c_args_f1")
    if [ -z "$curl_call" ]; then
        echo ""
    else
        echo "[INFO] PREDICTION OUTPUT:"
        echo $curl_call
    fi
}

check_arguments "$0" "$@"
node=$(get_node)
if [ -z  "$node" ]; then
  echo "[INFO] Node name unknown"
fi

echo "[INFO] Starting service"
start_service
echo "[INFO] Service started..."

is_deepaas_up

echo "[INFO] Let's call the web services here"
# ALL curl operations here...
id=$(get_model_id)
echo "ID="$id

if [ "${id}" != "Unknown" ]; then
    if [ "$train_args" ]; then
        train "$id" "$train_args"
    else
        if [ "$predict_arg" ]; then
            predict "$id" "$predict_arg"
        else
            echo "[INFO] Model loaded: $id. Prediction file name not provided. Exiting."
        fi
    fi

    # Remove all children started by the script
    echo ""
    echo "[INFO] Cleaning processes..."
    echo "[INFO] Killing PID=${SCRIPT_PID} with all its children (PGID=${SCRIPT_PID})"
    pkill -g $SCRIPT_PID
fi

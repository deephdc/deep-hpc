#!/bin/bash
#####################################
# Script to submit a job to slurm batch system
# 
# Parameters for SBATCH as defined in deepaas-hpc.sh
# --partition production
# --nodes=1
# --ntasks-per-node=8
# --time=3:00:00
# --job-name=deep
#####################################
DATENOW=$(date +%y%m%d_%H%M%S)
JOB2RUN="./deepaas-hpc.sh"
JOBLOG="${DATENOW}_deepaas_job.log"
### EXAMPLE FOR THE PREDICTION CALL
#JOBPARAMS="-o ${DATENOW}_deepaas.json -d St_Bernard_Dog_001.jpg"

### EXAMPLE FOR THE TRAINING CALL
JOBPARAMS="-o ${DATENOW}_deepaas.json -t num_epochs=15&run_info=True&network=Resnet50"

echo "Submitting $JOB2RUN.."
sbatch --output=$JOBLOG $JOB2RUN $JOBPARAMS

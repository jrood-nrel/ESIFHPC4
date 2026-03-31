#!/bin/bash

# user inputs
export DATA_DIR_PREFIX="/scratch/$USER/deepcam_numpy_preprocessed14Jan26" # path to preprocessed numpy-formatted data
export OUTPUT_DIR="/scratch/$USER/DeepCAM-testing/results/$SLURM_JOB_ID" # output directory for training logs

#### BASELINE/PORTED: CAN CHANGE THESE! ####
#export STAGE_DIR_PREFIX="$TMPDIR/deepcam_staging" # If this variable is missing, no data staging occurs.
export WIREUP_METHOD="nccl-slurm"
export DGXNGPU=4           # Number of accelerators per node
export MAX_THREADS=4       # Number of data loading threads per node
####

#### BASELINE/PORTED: DO NOT CHANGE THESE! ####
export LOGGING_FREQUENCY=1 # Must be set to 1 for 'Scenario 1'
export MAX_EPOCHS=3        # Must be set to 3 for 'Scenario 1'
export LOCAL_BATCH_SIZE=12 # Per-accelerator batch size
export START_LR=0.0001     # Starting learning rate. Roughly 10X lower than target end LR.
export LR_SCHEDULE_TYPE="cosine_annealing" # Learning rate scheduler type
export LR_WARMUP_STEPS=0   # Not necessary to set for 'Scenario 1'
export OPTIMIZER="AdamW"   # Learning rate optimizer
export WEIGHT_DECAY=0.2    # L2 regularization factor - 0.2 is good for AdamW, 0.01 good for LAMB
####

# common configuration settings
# note: CONFIG_DIR is set in run_and_time_kestrel.sh
source ${CONFIG_DIR}/config_common.sh

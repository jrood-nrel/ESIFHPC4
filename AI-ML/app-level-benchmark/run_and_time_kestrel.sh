#!/bin/bash

# The MIT License (MIT)
#
# Copyright (c) 2020-2023 NVIDIA CORPORATION. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

# CONFIG_DIR is the folder containing the config files (assumes they are in the same folder as this run script)
export CONFIG_DIR=$(dirname "$(realpath $0)")

# Load DeepCAM environment
module load mamba nccl/2.23.4_cuda124 cudnn
DEEPCAM_WORK_DIR=/projects/esifapps/$USER/DeepCAM-testing_torch2.9
mkdir -p $DEEPCAM_WORK_DIR
PYTHON_VERSION=3.11
PYTORCH_VERSION=2.9.0
ENV_NAME=${DEEPCAM_WORK_DIR}/deepcam-torch${PYTORCH_VERSION}-env-py${PYTHON_VERSION}_HPC-v3
eval "$(conda shell.bash hook)"
conda activate $ENV_NAME

# config*.sh controls many environment variables
# make sure the correct config file for the intended scenario is loaded!
source ${CONFIG_DIR}/config_scenario1.sh
# source ${CONFIG_DIR}/config_scenario2.sh 

# go to training code directory
cd deepcam-mlcommons-hpcv3/src/deepCam

# assemble run command (LOGGER, PROFILE_CMD, DEBUG_CMD, and RUN_CMD are set in config_common.sh)
# libmpi.so.12 is specifically being looked for. symlink this in a different directory
# to libmpi.so from system MPICH (a little hacky)
PSEUDO_LIB=`pwd`/lib && mkdir -p $PSEUDO_LIB
ln -s $CRAY_MPICH_DIR/lib/libmpi.so.12 $PSEUDO_LIB/libmpi.so.12
export LD_LIBRARY_PATH=$PSEUDO_LIB:$LD_LIBRARY_PATH
srun --overlap -u -N ${SLURM_NNODES} -n ${SLURM_NTASKS} -c ${SLURM_CPUS_PER_TASK} --cpu_bind=cores --gres=gpu:${SLURM_GPUS_ON_NODE} \
    ${LOGGER:-} ${PROFILE_CMD} ${DEBUG_CMD} $(which python) ${RUN_CMD}; ret_code=$?

if [[ $ret_code != 0 ]]; then exit $ret_code; fi

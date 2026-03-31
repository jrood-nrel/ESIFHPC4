#!/bin/bash
#SBATCH -A hpcapps
#SBATCH -J compile-torch
#SBATCH -t 01:30:00
#SBATCH -p debug
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=85G
#SBATCH --gres=gpu:1
#SBATCH -o %x-%j.out 

### DeepCAM environment installation ###

# Submit job from this directory to copy DeepCAM training code to DEEPCAM_WORK_DIR
JOB_SCRIPT_DIR=$(pwd)

# Create PyTorch environment in DeepCAM-testing folder
DEEPCAM_WORK_DIR=/projects/esifapps/$USER/DeepCAM-testing_torch2.9
mkdir -p $DEEPCAM_WORK_DIR
cd $DEEPCAM_WORK_DIR
export PARENT_FOLDER=`pwd`
PYTHON_VERSION=3.11
PYTORCH_VERSION=2.9.0
ENV_NAME=`pwd`/deepcam-torch${PYTORCH_VERSION}-env-py${PYTHON_VERSION}_HPC-v3_with_GTL

# Load modules and create base Python env
module load mamba nccl/2.23.4_cuda124 cudnn gcc-native/12.1
mamba create -y \
    --prefix $ENV_NAME \
    python=$PYTHON_VERSION \
    pip
eval "$(conda shell.bash hook)" && conda activate $ENV_NAME

# Clone PyTorch source code and install packages into Python env
if [ ! -d pytorch ]; then
    git clone --branch v${PYTORCH_VERSION} https://github.com/pytorch/pytorch.git
fi
cd pytorch
# sed -i 's| ; platform_machine .*"||' requirements.txt
pip install -r requirements.txt
# workaround for import error
echo "import numpy; numpy.version.version" > ${CONDA_PREFIX}/lib/python${PYTHON_VERSION}/site-packages/00-preload-numpy.pth

# DeepCAM dependencies
cd $DEEPCAM_WORK_DIR
echo "h5py
basemap
wandb
sympy
filelock
fsspec
jinja2
networkx
mlperf-logging
git+https://github.com/NVIDIA/mlperf-common.git
nvidia-ml-py
cupy
" > deepcam-requirements.txt
pip install -r deepcam-requirements.txt

# DeepCAM HPC v.3.0
# ml openmpi/4.1.6-nvhpc
MPICC=$(which mpicc) CFLAGS="-I${MPI_HOME}/include" pip install --no-binary=mpi4py --no-cache-dir mpi4py

# Set PyTorch compiliation variables
export CC=$(which gcc)
export CXX=$(which g++)
export MPICH_GPU_SUPPORT_ENABLED=1
export USE_CUDA=1
export CUDA_INCLUDE_DIRS=$CUDA_HOME/include
export USE_CUDNN=1
export USE_CUSPARSELT=1
export USE_XNNPACK=0
export USE_PYTORCH_QNNPACK=0
export USE_MPI=1
export USE_DISTRIBUTED=1
export TORCH_CUDA_ARCH_LIST=9.0
export CFLAGS="-Wno-error=maybe-uninitialized -Wno-error=uninitialized" 
export CXXFLAGS=$CFLAGS
export LD_LIBRARY_PATH=${CRAY_MPICH_ROOTDIR}/gtl/lib:${LD_LIBRARY_PATH}
export LDFLAGS="-ldl -L${CRAY_MPICH_ROOTDIR}/gtl/lib -lmpi_gtl_cuda" # required for PyTorch 2.9

# Configure and compile PyTorch against Kestrel's NCCL module
cd pytorch 
if [ -d build ]; then
   rm -rf build
fi
python setup.py clean

# compile torch
NCCL_ROOT_DIR=$NCCL_HOME \
NCCL_LIBRARIES=$NCCL_HOME/lib:$NCCL_HOME/plugin/lib \
NCCL_INCLUDE_DIRS=$NCCL_HOME/include \
USE_SYSTEM_NCCL=1 \
TORCH_C_FLAGS=$CFLAGS \
TORCH_CXX_FLAGS=$CXXFLAGS \
MAX_JOBS=${SLURM_CPUS_ON_NODE} \
PYTHON_EXECUTABLE=$(which python) \
CMAKE_PREFIX_PATH=$CONDA_PREFIX \
python setup.py install &> pytorch-install.log

# DALI - optional
pip install --extra-index-url https://pypi.nvidia.com --upgrade nvidia-dali-cuda120

# install IO Helpers package
cd $PARENT_FOLDER
cp -r ${JOB_SCRIPT_DIR}/deepcam-mlcommons-hpcv3 .
cd deepcam-mlcommons-hpcv3/io_helpers
python setup.py clean
python setup.py install
cd $PARENT_FOLDER

# APEX is required for LAMB optimizer
if [ ! -d apex ]; then
     git clone https://github.com/NVIDIA/apex
fi
cd apex
MAX_JOBS=$SLURM_CPUS_ON_NODE APEX_CPP_EXT=1 APEX_CUDA_EXT=1 pip install -v --no-cache-dir --no-build-isolation --disable-pip-version-check .


# Optional: install conda-pack to export and share environment with others on Kestrel
#mamba install conda-pack -y
#conda-pack -p $ENV_NAME -o deepcam-env.tar --ignore-missing-files

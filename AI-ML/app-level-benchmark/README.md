# AI-ML: "Scientific AI" Workload

## Purpose and Description

The purpose of this benchmark is to capture a 'typical scientific AI' workload performed by researchers at NLR, in which image segmentation tasks are common for various scientific purposes. As such, we employ a [DeepCAM model training implementation from MLCommons](https://github.com/mlcommons/hpc_results_v3.0), which segments long-term weather data from a large number of relatively small files. Due to the fact that NLR's current flagship HPC system, Kestrel, uses [NVIDIA accelerator hardware](https://www.nrel.gov/hpc/kestrel-system-configuration), note that our reference implementation is based on the NVIDIA submission to [MLCommons HPC Results v3.0](https://github.com/mlcommons/hpc_results_v3.0/tree/main/NVIDIA/benchmarks/deepcam/implementations/pytorch).

## How to build

### Step 1: PyTorch environment

Submitters are welcome to install PyTorch and the dependencies for DeepCAM into any reproducible environment (e.g., Python/conda virtual environments, containers, etc.). The instructions here describe a typical approach installing Python 3.12 within a baremetal `conda` environment as an example.

First, create a conda environment:

```
ENV_NAME=./deepcam-env
ml mamba
mamba create -y \
    --prefix $ENV_NAME \
    python=3.12
```

Next, activate the environment and choose **one** of the following approaches based on your hardware configuration to install PyTorch into your environment (taken from the [PyTorch documentation](https://pytorch.org/get-started/locally/)). If CUDA or ROCm versions of PyTorch are targeted, the appropriate GPU software environment should also be made available. **Note: although specific versions are listed in the `--index-url` as examples, we do not require any particular version of PyTorch or its dependencies to satisfy this benchmark.**

```
# Activate environment
conda activate $ENV_NAME

# Approach 1: NVIDIA CUDA-compatible torch
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130

# Approach 2: AMD ROCm-compatible torch
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.3

# Approach 3: Intel XPU-compatible torch
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/xpu

# Approach 4: CPU-only torch
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
```

*Any version of PyTorch that might be optimized for a targeted hardware architecture that is not mentioned above is acceptable for this benchmark, as long as the distribution is widely available and its results can be reproduced on any system hosting the hardware in question.*

### Step 2: DeepCAM

Install the DeepCAM Python package dependencies from pip and/or conda on inside the PyTorch environment from step 1. For an example, see the Slurm script [`prep-env-kestrel.sh`](prep-env-kestrel.sh) for reference instructions on how we created the appropriate PyTorch environment to run the DeepCAM benchmark. Note that on Kestrel, we explicitly compile PyTorch against a system module for NCCL that is configured to work with the HPE Slingshot network (`nccl/2.23.4_cuda124`) rather than using a precompiled version from pip. This step may not be necessary depending on the Offeror's hardware and network configuration.

The training scripts for DeepCAM do not require any special installation once the above environment is created. For convenience, this repository contains a lightly modified version of [the NVIDIA submission to MLCommons HPC Results v3.0](https://github.com/mlcommons/hpc_results_v3.0/tree/main/NVIDIA/benchmarks/deepcam/implementations/pytorch) (in `deepcam-mlcommons-hpcv3/`) to enable DeepCAM to run with newer versions (>=2.3.0) of PyTorch (specifically, by updating the calls to `MultiStepLRWarmup` and `CosineAnnealingLRWarmup` in `schedulers.py` to reflect the newer API). As demonstrated in the chunk above, the `io_helpers` package can also be installed from the submitted NVIDIA implementation folder.

Note: The specific packages mentioned in [`prep-env-kestrel.sh`](prep-env-kestrel.sh) may change depending on the type of accelerator being tested. As per our [general baseline run rules](../../README.md#draft-definitions-for-baselineas-is-ported-and-optimized-runs), the Offeror may freely substitute publicly available packages/libraries (and their subsequent calls in the training code itself) as necessary for baseline submissions.

### Step 3: Download and preprocess training data

Input training data can be downloaded via Globus using the [endpoint linked here](https://app.globus.org/file-manager?origin_id=0b226e2c-4de0-11ea-971a-021304b0cca7&origin_path=%2F). Note that the training data requires roughly 10TB of storage and contains HDF5-formatted files for training, validation, and test splits. 

Before training can occur, submitters must convert the HDF5-formatted input data into numpy format, following guidance from MLCommons HPC Results v3.0. Please see [`preprocess-deepcam-data.sh`](./preprocess-deepcam-data.sh) for instructions on how to preprocess the input data accordingly.

## Run Definitions and Requirements

## How to run

Once the training dataset has been prepared and the PyTorch environment has been set up, submitters may adapt from [`run_and_time_kestrel.sh`](./run_and_time_kestrel.sh) as an example for how to run the model. We require that submitters scale this benchmark across multiple nodes while using all available accelerators per node. Specifically, we require a submission using *N* nodes\*, 4*N* nodes, and 8*N* nodes to demonstrate multi-node scaling. 

\* *N* = The smallest possible number of nodes that can fit a DeepCAM training run. *N* is allowed to equal 1.

### Tests

## Run Rules

There are three types of submissions possible for this benchmark: *baseline*, *ported*, and *optimized*. Please see the ESIFHPC4 repo's [top-level README](../../README.md#draft-definitions-for-baselineas-is-ported-and-optimized-runs) for the constraints associated with each type of submission.

The ESIF-HPC-4 DeepCAM benchmark encompasses **two** types of scenarios:

- **Scenario 1.** The *local* (i.e., per-device) batch size is fixed to `12`. In this scenario, the reported metric is the average time required per training step over 3 epochs. Device-level "weak scaling" is intended to be measured in this scenario; this test should span *N*, *4N*, and *8N* nodes (in which *N* may equal 1) accordingly. We ask for 3 replicates for each node size, for a total of 9 runs. Model convergence is **not** required in this scenario. This scenario requires enabling verbose, per-step logging via the environment variable `LOGGING_FREQUENCY` - see [below](#baseline-scenario-1).
- **Scenario 2.** The *global* batch size is fixed to `1024`, with no specific requirement on the local batch size accordingly. In this scenario, the reported metric is the time required to reach an evaluation accuracy of 82%. This test should span *M*, *4M*, and *8M* nodes (in which *M* may equal 1) accordingly (*N* and *M* may vary between Scenario 1 and Scenario 2). We ask for 3 replicates for each node size, for a total of 9 runs. **Results from Scenario 2 are what will be considered as part of the overall throughput metric.**

**Summary of tests**

| Scenario | Number of nodes | Number of replicates |
| :---     | :---            | :---                 |
| 1        | *N*             | 3                    |
| 1        | *4N*            | 3                    |
| 1        | *8N*            | 3                    |
| 2        | *M*             | 3                    |
| 2        | *4M*            | 3                    |
| 2        | *8M*            | 3                    |

For convenience, we provide configuration file templates for Scenario 1 ([`config_scenario1.sh`](./config_scenario1.sh)) and Scenario 2 ([`config_scenario2.sh`](./config_scenario2.sh)). Environment variables that are either allowed to be freely changed or are required to be fixed for a [baseline submission](#baseline-submissions) are grouped accordingly in each file.

To run the DeepCAM benchmark, modify the provided `run_and_time_kestrel.sh` script and the appropriate config file based on the guidance below. Note that this script assumes access to a Slurm scheduler and is launched as a job via `sbatch -N <number_of_nodes> [submit_kestrel.sh](./submit_kestrel.sh)`. **If an alternative job scheduler is instead preferred, submitters are welcome to modify the launcher line `srun --overlap -u -N ${SLURM_NNODES} -n ${SLURM_NTASKS} -c ${SLURM_CPUS_PER_TASK} --cpu_bind=cores --gres=gpu:${SLURM_GPUS_ON_NODE}` as needed.** Lines under `# Load DeepCAM environment` will need to be modified to reflect the submitter's specific DeepCAM environment setup. Further, note that the appropriate config file will have to be sourced based on the scenario intended to be run.

### Baseline submissions

For *baseline* submissions, please use the following default runtime parameters set in [`config_scenario1.sh`](./config_scenario1.sh) or [`config_scenario2.sh`](./config_scenario2.sh) (see above), which is what we deploy on Kestrel. You will need to set the variables marked under the `# user inputs` sections appropriately (e.g., input/output locations for the run). 

Training scripts for *baseline* submissions must be forked from a [DeepCAM model training implementation hosted by MLCommons HPC Results v3.0](https://github.com/mlcommons/hpc_results_v3.0/tree/main). Using additional Python packages (i.e., anything other than what is required for PyTorch and the DeepCAM training scripts) is *not* allowed for baseline submissions.

#### Baseline Scenario 1

The following environment variables set in [`config_scenario1.sh`](./config_scenario1.sh) **can** be freely modified as necessary for *baseline* Scenario 1 submissions:

| Variable           | Description                              | Default Kestrel value  |
| :--                | :--                                      | :--                    |
| `STAGE_DIR_PREFIX` | Path to data staging directory           | Stages input data to this directory (e.g., one on a faster filesystem or local node SSD.) If this variable is not set, then data staging does not occur (default). |
| `WIREUP_METHOD`    | Method for distributed process communication | Options are 'nccl-slurm' (default), 'nccl-openmpi', 'nccl-file', 'mpi', or 'dummy' |
| `DGXNGPU`          | Number of accelerators per node          | `4`                    |
| `MAX_THREADS`      | Number of data loading threads per node  | `4`                    |


The following environment variables set in [`config_scenario1.sh`](./config_scenario1.sh) **must be set** for *baseline* **Scenario 1** submissions:

| Variable                 | Description                                                         | Required value           |
| :--                      | :--                                                                 | :--                      |
| `LOGGING_FREQUENCY`      | Whether to gather logs per-step (`1`) or per-epoch (`0`)            | `1`                      |
| `MAX_EPOCHS`             | Number of epochs at which training ends, regardless of convergence. | `5`                      |
| `LOCAL_BATCH_SIZE`       | Per-accelerator batch size                                          | `12`                     |
| `START_LR`               | Starting learning rate                                              | `0.0005`                 |
| `LR_SCHEDULE_TYPE`       | Learning rate scheduler type                                        | `cosine_annealing`       |
| `LR_WARMUP_STEPS`        | Number of LR warmup steps                                           | `0`                      |
| `OPTIMIZER`              | Learning rate optimizer                                             | `AdamW`                  |
| `WEIGHT_DECAY`           | Strength of L2 regularization                                       | `0.2`                    |


#### Baseline Scenario 2

The following environment variables set in [`config_scenario2.sh`](./config_scenario2.sh) **can** be freely modified as necessary for *baseline* Scenario 2 submissions:

| Variable           | Description                              | Default Kestrel value  |
| :--                | :--                                      | :--                    |
| `STAGE_DIR_PREFIX` | Path to data staging directory           | Stages input data to this directory (e.g., one on a faster filesystem or local node SSD.) If this variable is not set, then data staging does not occur (default). |
| `WIREUP_METHOD`    | Method for distributed process communication | Options are 'nccl-slurm' (default), 'nccl-openmpi', 'nccl-file', 'mpi', or 'dummy' |
| `DGXNGPU`          | Number of accelerators per node          | `4`                    |
| `MAX_THREADS`      | Number of data loading threads per node  | `4`                    |
| `LOCAL_BATCH_SIZE` | Per-accelerator batch size               | Depends on number of GPUs used (`DGXNGPU`\*`Number of nodes`\*`LOCAL_BATCH_SIZE` must equal `1024`). |

The following environment variables set in [`config_scenario2.sh`](./config_scenario2.sh) **must be set** for *baseline* Scenario 2 submissions:

| Variable                 | Description                                                         | Required value           |
| :--                      | :--                                                                 | :--                      |
| `LOGGING_FREQUENCY`      | Whether to gather logs per-step (`1`) or per-epoch (`0`)            | `0`                      |
| `MAX_EPOCHS`             | Number of epochs at which training ends, regardless of convergence. | `50`                     | 
| `START_LR`               | Starting learning rate                                              | `0.0005`                 |
| `LR_SCHEDULE_TYPE`       | Learning rate scheduler type                                        | `cosine_annealing`       |
| `LR_WARMUP_STEPS`        | Number of LR warmup steps                                           | `0`                      |
| `OPTIMIZER`              | Learning rate optimizer                                             | `AdamW`                  |
| `WEIGHT_DECAY`           | Strength of L2 regularization                                       | `0.2`                    |

### Ported submissions

For *ported* submissions, the *baseline* parameters must be used, though training code modifications necessary to port the code to a new/different device architecture are also permitted. **This includes replacing any vendor-specific package/library imports and calls in the training code.** As described in the repository's [top-level README](../../README.md#draft-definitions-for-baselineas-is-ported-and-optimized-runs), *ported* submissions should not be reported without *baseline*, unless *baseline* is not possible.

### Optimized submissions

#### Optimized Scenario 1

*Optimized* submissions are encouraged (though optional) as part of Scenario 1. The same environmental variables set in [*baseline* Scenario 1](#baseline-scenario-1) must be used in an *optimized* Scenario 1 submission, although the code itself is allowed to be modified to best optimize performance and demonstrate hardware capabilities. We require that any of these changes are reported and reproduceable. **Note that only results from Scenario 2 will be considered for the overall throughput metric.**

#### Optimized Scenario 2

*Optimized* submissions are encouraged (though optional) as part of Scenario 2. For *optimized* Scenario 2 submissions, the required parameters used for [*baseline* Scenario 2 submissions](#baseline-scenario-2), all other hyperparameters (see in [`config_scenario2.sh`](./config_scenario2.sh)), and the training code itself are allowed to be modified to best optimize performance and demonstrate hardware capabilities. We require that any of these changes are reported and reproduceable. **Note that only results from Scenario 2 will be considered for the overall throughput metric.**


## Benchmark test results to report and files to return

**We will provide a convenience wrapper script to extract the data requested to be reported from each DeepCAM submission scenario at a later date.**

### Scenario 1 submissions

Noting the median time required per training step (in seconds) across 5 epochs satisfies this submission. This time should **solely** reflect the time spent during training itself. In other words, this excludes the time required for model initiation and the time spent staging data to local disks for faster I/O. 

For each run following Scenario 1 rules, we request the following information in the table below. 

| Run Type  | Scenario | Nodes used | Replicate | Accelerators per node | Total Accelerators | Local Batch Size | Data staged | Median time per training step (seconds)  |
| :---      | :---     | :---       | :---      | :---                  | :---               | :---             | :---        | :---                                     |
| baseline  | 1        | 1          | 1         | 4                     | 4                  | 12               | No          | 0.732                                    |
| baseline  | 1        | 4          | 1         | 4                     | 16                 | 12               | No          | 0.749                                    |
| baseline  | 1        | 8          | 1         | 4                     | 32                 | 12               | No          | 0.756                                    |
| optimized | 1        | *N*        | *R*       | *X*                   | :---               | *Y*              | *<Yes/No>*  | *T*                                      |
| optimized | 1        | *4N*       | *R*       | *X*                   | :---               | *Y*              | *<Yes/No>*  | *T*                                      |
| optimized | 1        | *8N*       | *R*       | *X*                   | :---               | *Y*              | *<Yes/No>*  | *T*                                      |


### Scenario 2 submissions

Noting the time required (in minutes) to reach 82% validation accuracy satisfies this submission. As with Scenario 1, this time should **solely** reflect the time spent during training itself. In other words, this excludes the time required for model initiation and the time spent staging data to local disks for faster I/O. 

For each run following Scenario 2 rules, we request the following information (using unoptimized Kestrel reference data as an example):

| Run Type  | Scenario | Nodes used | Replicate | Accelerators per node | Total Accelerators | Local Batch Size | LR Scheduler     | Start LR  | Optimizer   | Median timing per epoch (minutes) | Total Time Required* (minutes) | Epochs Required* |
| :---      | :---     | :---       | :---      | :---                  | :---               | :---             | :---             | :---      | :---        | :---                              | :---                           | :--              |
| baseline  | 2        | 16         | 1         | 4                     | 64                 | 16               | cosine_annealing | 0.0005    | AdamW       | X                                 | 118.12                         | 49               |
| baseline  | 2        | 32         | 1         | 4                     | 128                | 8                | cosine_annealing | 0.0005    | AdamW       | X                                 | 68.63                          | 48               |
| optimized | 2        | *M*        | *R*       | *X*                   | *X\*M*             | *Y*              | *scheduler*      | *Z*       | *optimizer* |                                   | *T*                            | *E*              |

\* Time or epochs required to reach 82% evaluation accuracy target.

## References and useful links

* [MLCommons HPC v3.0 Results](https://github.com/mlcommons/hpc_results_v3.0)
* [Exascale Deep Learning for Climate Analytics paper](https://arxiv.org/pdf/1810.01993)
* [NERSC10 DeepCAM reference](https://gitlab.com/NERSC/N10-benchmarks/deepcam)
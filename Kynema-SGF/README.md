# Kynema-SGF

## Description

Kynema-SGF is a massively parallel, block-structured adaptive-mesh refinement (AMR), incompressible flow solver. It depends on the AMReX library that provides mesh data structures, mesh adaptivity, and linear solvers to handle its governing equations. This software is part of the Kynema ecosystem, and is available [here](https://github.com/kynema/Kynema-SGF). The Kynema-SGF benchmark is useful as it is very sensitive to MPI performance due to all-reduce and all-to-all type MPI operations within AMReX's builtin MLMG solvers in which Kynema-SGF utilizes. MPI performance is typically the bottleneck for Kynema-SGF since Kynema-SGF does little computation per cell.

## Licensing

Kynema-SGF is licensed under BSD 3-clause license. The license is included in the source code repository, [LICENSE](https://github.com/Kynema/kynema-sgf/blob/main/LICENSE).

## Building

Kynema-SGF utilizes the AMReX library and therefore runs on CPUs, or NVIDIA, AMD, or Intel GPUs. Kynema-SGF uses CMake for its local build system. Explicit instructions for building Kynema-SGF are provided in this repo as shown in the scripts in this directory we used to run the benchmark, while more general information for building Kynema-SGF can be found [here](https://kynema.github.io/kynema-sgf/user/build.html). In this repo we provide the build scripts that were used to run the benchmarks shown in the plot for CPUs, GPUs, as well as a case using GPU-aware MPI. These scripts show exactly how the benchmarks were run to obtain results on the Kestrel machine, where the specific cases will be discussed in the next section.

The following script completed the runs on the CPUs using the CPU benchmark case and performed a strong scaling. Our best performance on the Kestrel machine uses 72 ranks per node with specific process bindings shown in the scripts. Kynema-SGF is configured in this case to run calculatons for 20 timesteps and perform no I/O:
[kynema-sgf-benchmark-cpu.sh](kynema-sgf-benchmark-cpu.sh)

This script completed a single run on the CPUs using the CPU benchmark on 4 nodes. Kynema-SGF is configured in this case to run calculatons for 20 timesteps and perform plot output at step 20. This plot output contains the physical quantities involved in the simulation:
[kynema-sgf-benchmark-cpu-verify.sh](kynema-sgf-benchmark-cpu-verify.sh)

This script completed a strong scaling on the GPUs using the GPU benchmark case which has 4x the number of cells as the CPU case. Again, it runs for 20 timesteps with no I/O using 1 MPI rank per GPU:
[kynema-sgf-benchmark-gpu.sh](kynema-sgf-benchmark-gpu.sh)

This is the same as the previous GPU case but with GPU-aware MPI enabled on Kestrel:
[kynema-sgf-benchmark-gpu-aware.sh](kynema-sgf-benchmark-gpu-aware.sh)

This is the same as the previous GPU case but is run as a single simulation with plot output done at timestep 20 similar to the CPU verification:
[kynema-sgf-benchmark-gpu-verify.sh](kynema-sgf-benchmark-gpu-verify.sh)

## Running the Benchmark

### Benchmark Case Description

We create a benchmark case on top of our standard [abl_godunov regression test](https://github.com/Kynema/kynema-sgf/blob/main/test/test_files/abl_godunov/abl_godunov.inp) by adding runtime parameters on the command line. This case is designed to be either weak-scaled or strong scaled. This simulation runs a simple atmospheric boundary layer (ABL) that stays fixed in the Z dimension, but can be scaled arbitrarily in the X and Y dimensions. We also add a single refinement level across the middle of Z dimension to complete the exercising of the full AMR algorithm. 

Below, we show the CPU case done as a weak scaling merely to show that if different sizes of the simulation make more sense to run on other machines, this how one can weak scale it:

```
srun kynema_sgf abl_godunov.inp ${FIXED_ARGS} amr.n_cell=64 64 64 geometry.prob_hi=1024.0 1024.0 1024.0
srun kynema_sgf abl_godunov.inp ${FIXED_ARGS} amr.n_cell=128 128 64 geometry.prob_hi=2048.0 2048.0 1024.0
srun kynema_sgf abl_godunov.inp ${FIXED_ARGS} amr.n_cell=256 256 64 geometry.prob_hi=4096.0 4096.0 1024.0
srun kynema_sgf abl_godunov.inp ${FIXED_ARGS} amr.n_cell=512 512 64 geometry.prob_hi=8192.0 8192.0 1024.0
srun kynema_sgf abl_godunov.inp ${FIXED_ARGS} amr.n_cell=1024 1024 64 geometry.prob_hi=16384.0 16384.0 1024.0
srun kynema_sgf abl_godunov.inp ${FIXED_ARGS} amr.n_cell=2048 2048 64 geometry.prob_hi=32768.0 32768.0 1024.0
```

Note that `amr.n_cell` refers to the number of cells in the outermost refinement layer as `amr.n_cell=x_cells y_cells z_cells`. `z_cells` remains fixed at 64. As `x_cells` and `y_cells` are increased, the corresponding spatial dimensions must be scaled accordingly in order to keep the cell size the same. This is controlled by `geometry.prob_hi=x_dim y_dim z_dim`. `z_dim` remains fixed at 1024 while `y_dim` and `x_dim` are increased proportional to the increase in `y_cells` and `x_cells` respectively.


## Running

The [run-all.sh](run-all.sh) script shows the nodes on the Kestrel machine in which each script of the specific benchmark was run. Note the scripts are provided as an exact blueprint of how our reference results were obtained and it is not expected they are to be followed exactly on other hardware. After building with the steps shown in the provided scripts. The scripts also show how the strong scaling was run. Once the simulations completed, the averaging scripts were run, then the total number of cells in the simulation were added together and divided by the number of CPU cores or GPUs. The average time per timestep was then plotted against the cells per CPU core or GPU. 

To get the average of the time per timestep for our strong scaling plot, we used two scripts that focus on averaging the `Total` time per timestep over 20 timesteps. One bash extracts the Kynema-SGF wallclock times for all cases run and one python script finds the mean. These are also generated from within the scripts provided in this repo. Once the cases are run, one can use `bash kynema-sgf-average.sh` in each directory to generate an `kynema-sgf-avg.txt` file with the average time per timestep of each case. The number of cells in the Kynema-SGF simulations is reported at the start of the simulation with the number of cells for each level. These numbers can be added together and divided by the number of CPU cores or GPUs in which the case was using to get the cells per CPU core or GPU. For our results, this calculation was done manually and put into the [LaTeX plot code](kynema-sgf-strong-scaling-abl.tex). This shows exactly how our results were plotted from the information in the logs from the Kestrel benchmark runs, relating the time per timestep to the number of cells per core or GPU.

kynema-sgf-average.py:
```
#!/usr/bin/env python3

import argparse
import pandas as pd
import numpy as np

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="A simple averaging tool")
    parser.add_argument(
        "-f",
        "--fnames",
        help="Files to average",
        required=True,
        nargs="+",
        type=str,
    )
    args = parser.parse_args()

    for fname in args.fnames:
        data = pd.read_csv(fname, sep="\\s+", skiprows=0, header=None)
        array = data.to_numpy()
        print(np.mean(array[:]))
```

kynema-sgf-average.sh:
```
#!/bin/bash

set -e

i=1
for file in $(ls -d1 kynema-sgf-benchmark* | sort -V); do
    echo "$file"
    grep ^WallClockTime "$file" | awk '{print $NF}' > kynema-sgf-time-$i.txt
    bash kynema-sgf-average.py -f kynema-sgf-time-$i.txt >> kynema-sgf-avg.txt
    rm kynema-sgf-time-$i.txt
    ((i=i+1))
done
```

Kynema-SGF is able to run on different GPUs using the CMake configuration parameters: `KYNEMA_SGF_ENABLE_CUDA`, `KYNEMA_SGF_ENABLE_ROCM`, or `KYNEMA_SGF_ENABLE_SYCL`, for NVIDIA, AMD, or Intel GPUs, respectively. GPU-aware MPI is also available in AMReX, and therefore Kynema-SGF, which can benefit performance. The GPU-aware MPI library can be injected and linked during the CMake build however one sees fit. During runtime AMReX provides a `amrex.use_gpu_aware_mpi` parameter which can be set to 1 (`amrex.use_gpu_aware_mpi=1`) on the command line as shown in our example script.

Although Kynema-SGF is able to utilize threading through OpenMP, it is not currently used. Therefore, we are only interested in performance for flat MPI without threading. The CMake option `KYNEMA_SGF_ENABLE_OPENMP` defaults to `OFF` and should not be enabled.

### Verification

To verify that the results are close to expected, we compare the physical quantities of the plots output from Kynema-SGF at time step 20 from our reference case running on 4 nodes in both the CPU and GPU cases. The AMReX tool used for comparing two plots is the `amrex_fcompare` executable, which is built automatically in the verify scripts. The location of `amrex_fcompare` is in `kynema-sgf-build/submods/amrex/Tools/Plotfile/amrex_fcompare`. The input for this program is two plotfiles and the output is a norm of the differences between all the variables in each AMR level in the simulation. Note the output from Kynema-SGF on the CPUs is generally deterministic between runs. However, when running Kynema-SGF on GPUs, output is nondeterministic (due to order of operations not being guaranteed in AMReX's MLMG solver), making it more difficult to understand if the results are sufficiently within bounds.

We provide a reference plot file from both our CPU case and GPU case, in which to compare. To use `fcompare`, it can run in serial as such:

```
/path/to/kynema-sgf-benchmark-cpu-verify/kynema-sgf-build/submods/amrex/Tools/Plotfile/amrex_fcompare kynema_sgf_cpu_reference_plt00020 /other/path/to/kynema-sgf-benchmark-cpu-verify/kynema-sgf-build/test/test_files/abl_godunov/plt00020
```

Note `fcompare` is an MPI application so it can be run with multiple ranks when the plot files are large. We expect differences due to different machines and compilers, etc. We expect the differences to be small for CPUs, but larger for GPUs. Although tolerances can be provided to fcompare to make it a boolean check (where we list a tolerance below), we also request that the output of fcompare is provided so it can be intepreted by a human. The same can be done for the GPU case using the provided GPU reference plot file.

Output from fcompare when running the CPU case on the reference machine and comparing it to the CPU reference plot can be seen [here](kynema-sgf-benchmark-kestrel-results/kynema-sgf-benchmark-cpu-fcompare-results.txt). Note it's deterministic between runs and it was run with multiple MPI ranks.

Output from fcompare when running the GPU case on the reference machine and comparing it to the GPU reference plot can be seen [here](kynema-sgf-benchmark-kestrel-results/kynema-sgf-benchmark-gpu-fcompare-results.txt). Note it's nondeterministic between runs, but close to machine precision when run twice on the same machine.

If a calculation exceeds `1e-10` in both absolute and relative error in any quantity output by `fcompare`, it should be considered to have failed the validation check.

Also of note, when Kynema-SGF is built for the GPU, `fcompare` from that build will run on the GPU as well. We used the CPU `fcompare` executable for comparing our both our CPU and GPU plot files in these benchmarks to be consistent.

## Rules

* The offeror may freely adapt the build and run scripts provided here so long as the `FIXED_ARGS` are not modified and the other run rules in this list are adhered to.
* For baseline CPU submissions, we request that at least 80% of CPU cores are utilized. Optimized CPU submissions may use any number of cores. Please note that all CPU submissions are optional.
* Our reference GPU results were obtained with 1 rank per GPU for Kynema-SGF; however, if running multiple ranks per GPU is beneficial, that is allowed.
* Baseline results must be submitted with Kynema-SGF version 3.8.0. Optimized submissions may use any version.
* All submissions must use only FP64, even though reduced precision capability is available in later releases.
* For (optional) optimized submissions, any optimizations would be allowed in the code, build, and task configuration as long as the offeror would provide a high-level description of the optimization techniques used and their impact on performance in the response. Please note that this is more permissive than the "default" baseline/ported/optimized rules in that these optimizations do not need to be made available in a "maintainable" form.

### Test case definitions

Please note that, in an effort to increase the tractability of the overall benchmarking suite, a response to the CPU test case is optional. Any CPU results returned, whether obtained from a test system or from a projection, are valued.

#### Baseline test case

The baseline test case for GPUs should be run with `amr.n_cell=1024 1024 64` and `geometry.prob_hi=16384.0 16384.0 1024.0`

The baseline test case for CPUs should be run with `amr.n_cell=512 512 64` and `geometry.prob_hi=8192.0 8192.0 1024.0`, which is 1/4th the problem size of the GPU case in terms of cell count. 

That the cell counts differ between CPU and GPU test cases is an intentional choice that reflects how Kynema-SGF simulations are typically chosen to run on CPU or GPU. The CPU case represents the largest possible problem size that can be executed on the CPU nodes of the reference system without running out of memory, and likewise for the GPU case. GPUs are usually used to increase the problem size that be simulated with an "equivalent" amount of hardware nodes, moreso than directly increasing the time per timestep of an identical calculation to the CPU case.

The computational cost of this benchmark scales approximately linearly with the number of cells in the simulation domain. I.e., on the same hardware, an otherwise identical simulation but with 4x the cell count would expect to run in approximately 4x the amount of time.

For both the GPU and (optional) CPU baseline test cases, a strong scaling series of 1, 2, 4, and 8 nodes should be returned. 

#### (Optional) Optimized test case

In addition to the permissive "optimized" case rules laid out under [Rules](#Rules), we allow for two types of additional tests to be submitted:

1. The offeror may modify the simulation such that the number of cells in the x- and y-directions are increased to the maximum possible on a single node before running out of memory, then report a strong scaling series at this cell count. 
2. The offeror may present a weak-scaling series where the number of cells at every node count is increased to the maximum possible before running out of memory.

#1 represents a strong scaling series whose simulation size has been tuned to produce optimal performance on the offered hardware. #2 represents a common means through which Kynema-SGF users take advantage of the HPC system (i.e., by direct increase of the problem size itself).

For either case, please refer to the [Benchmark Case Description](#benchmark-case-description) section for instructions on how to increase the system size.

## Results to return

1. The logs from the runs.
2. The completed tables shown below for the offeror system. Similar for any weak scaling cases provided.
3. Results from `fcompare` for correctness verification.
4. Description of any code optimizations performed in the optimized case.

| Benchmark | GPUs         | MPI Ranks| Steps  | Cells/GPU | Time Per Timestep(s)     |
|:---------:|:------------:|:--------:|:------:|:---------:|:------------------------:|
|   GPU     |       4      |    4     |  20    |  83886080 |    2.49550               |
|   GPU     |       8      |    8     |  20    |  41943040 |    1.40124               |
|   GPU     |       16     |    16    |  20    |  20971520 |    0.83400               |
|   GPU     |       32     |    32    |  20    |  10485760 |    0.55235               |
|   GPU     |       64     |    64    |  20    |  5242880  |    0.38498               |
|   GPU     |       128    |    128   |  20    |  2621440  |    0.30915               |


| Benchmark | Cores        | MPI Ranks| Steps  | Cells/Core | Time Per Timestep(s)     |
|:---------:|:------------:|:--------:|:------:|:----------:|:------------------------:|
|   CPU     |       72     |    72    |  20    |  806596    |    11.1510               |
|   CPU     |       144    |    144   |  20    |  403298    |    6.18195               |
|   CPU     |       288    |    288   |  20    |  201649    |    5.34305               |
|   CPU     |       576    |    576   |  20    |  100824    |    4.01630               |
|   CPU     |       1152   |    1152  |  20    |  50412     |    3.73549               |
|   CPU     |       2304   |    2304  |  20    |  25206     |    3.08605               |
|   CPU     |       4608   |    4608  |  20    |  12603     |    2.81844               |
|   CPU     |       9216   |    9216  |  20    |  6301      |    2.30490               |

The output from all the runs used to create the plot of the results from the Kestrel reference machine are provided [here](kynema-sgf-benchmark-kestrel-results) as a reference.

The Kynema-SGF-specific information should can also be provided in the Excel spreadsheet which includes the other benchmarks, in the Kynema-SGF tab.

Below is the plot of the results of the Kestrel reference system. Note the "naive" case is only shown to help display that Kestrel requires a very specific 72 rank per node configuration with specific process bindings on nodes with 2 network interconnect devices to achieve good performance for Kynema-SGF. The "ideal" lines illustrate perfect linear scaling in each case.

![Kynema-SGF Strong Scaling](https://github.com/NREL/ESIFHPC4/blob/main/Kynema-SGF/kynema-sgf-strong-scaling-abl.tex.png?raw=true)

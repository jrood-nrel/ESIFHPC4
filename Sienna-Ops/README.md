
# Sienna

## Purpose and Description

The purpose of this benchmark is to test the functionality of the Julia programming language, the Sienna framework, and two types of solvers commonly used to solve optimization problems for power grid operations and planning: interior point and mixed integer solvers. The **Sienna framework** is an open-source ecosystem for simulation and optimization of modern energy systems. It is designed to model, solve, and analyze scheduling problems and dynamic simulations of quasi-static infrastructure systems.

Sienna consists of three main modules: **Sienna\Data**, **Sienna\Dyn**, and **Sienna\Ops**. This benchmark will focus on exercising **Sienna\Ops**, which enables simulation of system scheduling, including unit commitment, economic dispatch, automatic generation control, and nonlinear optimal power flow. The framework applies advanced computer science, visualization, applied mathematics, and computational science to create a flexible modeling environment for energy systems.

Users running this benchmark will be interacting primarily with `PowerSystems.jl` and `PowerSimulations.jl` packages from the Sienna framework.
`PowerSystem.jl` is the package that is used for creating and storing the power system that is being modeled. It stores the system as a JSON file and uses an H5 file to store timeseries data.
`PowerSimulations.jl` uses the `sys.json` created and loaded into the memory by PowerSystems.jl to create a simulation model and solve it using an MILP or NLP solver such as HiGHS or IPOPT, respectively.

## Licensing Requirements

Sienna is open-source software. Licensing details for its components can be found on the [Sienna GitHub repository](https://github.com/NREL-Sienna). 

## Other Requirements

Sienna requires Julia as the primary programming language and depends on several Julia packages, including `PowerSimulations.jl` and `PowerSystems.jl`.

## How to build and Run

### Instructions to build and install Sienna components:

1. Install Julia from [JuliaLang.org](https://julialang.org/). Specifically, we recommend using the [Manual Downloads](https://julialang.org/downloads/manual-downloads/), and selecting the current stable release appropriate for the target architecture. Below we show two options for building the Julia environment. 

#### Option 1: Use existing Project.toml and Manifest.toml files
2. Instantiate the `Project.toml` and `Manifest.toml` files in this directory. On 
the terminal, assuming that you are in the same directory as this
README.md, run
   ```shell
   julia --project=.
   ```
   ```julia
   ] instantiate
   ```
   This should install all the packages needed to run the benchmark

#### Option 2: Build your own Julia environment

2. Add the required packages using the Julia package manager:
   ```julia
   ] add PowerSimulations PowerSystems@4 HydroPowerSimulations PowerSystemCaseBuilder
   ```
3. Addtional tools used in the benchmark:
   ```julia
   ] add BenchmarkTools CSV DataFrames
   ```
4. Add requisite solvers
   ```julia
   ] add HiGHS IPOPT
   ```

### Instructions on how to run the Sienna benchmark:

#### Running the benchmark from the command line
1. Run the benchmark as follows
   ```shell
   julia --threads=auto --project=. small/run_RTS_UC-ED.jl
   ```

#### How we ran this benchmark on Kestrel:
1. Modify and run the sbatch file `run_benchmarks.sh` as follows

   ```shell
   sbatch run_benchmarks.sh 1 
   sbatch run_benchmarks.sh auto
   ```

Note: The argument after `run_benchmarks.sh` specifies how many threads julia should be started with. By default, Julia uses only one thread. Setting the number of threads to `auto` means that Julia will set the number of threads to be equal to the number of cores on the system.

## Run Definitions and Requirements

- The benchmark includes:
  - Unit Commitment and Economic Dispatch simulations using `PowerSimulations.jl`.
- The input data for these simulations is compatible with `PowerSystems v4.0`.

Note: There is a new version of Sienna that uses `PowerSystems v5.0`. However, this benchmark uses `PowerSystems v4.0`. Data sets and code may be updated to work with the latest version of Sienna, but this is not required. 

## Run Rules

- The Benchmark is single node only.
- GPU-compatible Optimizers that are compatible with Julia JuMP may be exercised on GPU nodes if desired. However, this is not a requirement.
- This benchmark has been set up to run using two open source solvers: IPOPT and HiGHS. Proprietary solvers such as Gurobi and Xpress may be used instead, but are not required.

## Benchmark test results to report and files to return

The benchmark creates timing, memory, and allocation data that can be inspected visually for comparison. An output summary text file and CSV file are created in `small/benchmark_results` that include these data. These are the files to return. We emphasize, however, that this is only a functionality test, and will not be judged by computation time, answer correctness, etc.

Also produced by our script `run_benchmarks.sh` is a file containing information printed by Sienna during the solve process (e.g., fout_RTS_UC-ED_auto.out). This file is not required. 

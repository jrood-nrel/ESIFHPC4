# WRF Benchmarking

Weather Research and Forecasting (WRF) benchmarking and building instructions. This document is organized as follows:

1. [Step 1: Building WRF](#step-1-building-wrf): This describes the process required to build the WRF executable from source code.
2. [Step 2: Submitting Benchmarking Jobs](#step-2-submitting-benchmarking-jobs): This described how to access the benchmarking job and modify it to test our WRF installation.
3. [Step 3: Measuring and Recording Performance](#step-3-measuring-and-recording-performance): This section defines what metrics will be recorded and how to calculate them.
4. [Run Definitions and Requirements](#run-definitions-and-requirements): We outline what results to include in the response and give examples for comparison.

---

## Step 1: Building WRF

### 1.1: Download WRF Source Code
Start by downloading the source code for WRF. Use the provided links to download the latest version of WRF (v4.7.1 at the time of this writing, newer versions are acceptable for this benchmark). The command below will fetch a compressed `.tar.gz` archive from the official WRF GitHub repository.

```bash
wget https://github.com/wrf-model/WRF/releases/download/v4.7.1/v4.7.1.tar.gz
```

### 1.2: Extract the Source Code
Once you've downloaded the archive, unpack it to access the source code. The `tar` command extracts the contents of the `.tar.gz` files and creates directories corresponding to the source files, in this case, WRF (WRFV4.7.1).

```bash
tar -xvzf v4.7.1.tar.gz 
```

### 1.3: Load Necessary Dependencies
The next step is loading the required software dependencies. For this benchmark, we require the use of PnetCDF, NetCDF, and HDF5. In the below example, we show how to build with a GNU toolchain, but the offeror may opt to use a different toolchain.

For the reference system, we use the following toolchain, with versions of each package denoted after the `/` in their names:

```bash
PrgEnv-gnu/8.5.0
gcc/12.1
cray-mpich/8.1.28
hdf5/1.14.6
netcdf/4.9.3
pnetcdf/1.14.0
```

### 1.4: Set Environment Variables
Define environment variables to facilitate the compilation process. These variables specify file paths, library locations, and directory structures required by the build system. Update the path of `WRF_DIR` in the example to match your local installation setup. In our example, we use the following:

```bash
export PATH="/usr/bin:${PATH}"
export LD_LIBRARY_PATH="/usr/lib64:${LD_LIBRARY_PATH}"

export WRF_DIR=/scratch/<user>/<benchmark_folder>/WRFV4.7.1/

# Specific to reference system
export PNETCDF=$PNETCDF_DIR 
export HDF5=$HDF5_DIR
```

### 1.5: Configure WRF Build Options
Navigate to the WRF directory specified earlier using the `WRF_DIR` variable. Run the `configure` script, which will ask you to specify build options. At the first prompt, select an option appropriate for your toolchain which compiles WRF with support for shared memory (SM) and distributed memory (DM) parallelism. In our example, we choose option `35` for `(dm+sm) GNU (gfortran/gcc)`. At the second prompt, specify the type of nesting desired by selecting option `1=basic`. Nesting allows for finer resolution within a defined area.

```bash
cd ${WRF_DIR}
./configure
```

First prompt:
```bash
Enter selection [1-83] : 35
```

Second prompt:
```bash
Compile for nesting? (1=basic, 2=preset moves, 3=vortex following) [default 1]:1
```

### 1.6: Compile WRF
Compile WRF with `./compile em_real`. Upon successful compilation, you should see a summary of executables created in the `main` directory (e.g., `wrf.exe`, `real.exe`). For example:

```bash
./compile -j 16 em_real
```

where the summary of executables upon compilation should look similar to:

```bash
build started:   Wed Nov 12 15:14:18 MST 2025
build completed: Wed Nov 12 15:17:30 MST 2025
 >                  Executables successfully built                  
 
-rwxrwxr-x 1 <user> <user> 39826880 Nov 12 15:17 main/ndown.exe
-rwxrwxr-x 1 <user> <user> 36185816 Nov 12 15:17 main/real.exe
-rwxrwxr-x 1 <user> <user> 35632920 Nov 12 15:17 main/tc.exe
-rwxrwxr-x 1 <user> <user> 45807024 Nov 12 15:17 main/wrf.exe
```

> [!TIP]  
> The configuration log produced by carrying out the above sequence of operations on the reference system is included here: [configure.wrf](build_logs/configure.wrf).


---

## Step 2: Setting up the Benchmarking Test Case

### 2.1: Download and Extract Benchmark Data
Download the 2.5-km CONUS benchmark dataset (~34GB). These files include the inputs, supporting scripts, and truth values required to perform the benchmarking. Unpack the files after download to expose the necessary files for the test cases.

```bash
wget https://www2.mmm.ucar.edu/wrf/users/benchmark/v44/v4.4_bench_conus2.5km.tar.gz
tar -xvzf v4.4_bench_conus2.5km.tar.gz
cd v4.4_bench_conus2.5km
```

### 2.2: Modify Benchmark File for Parallel NetCDF
We will make a slight modification to the provided `namelist.input` file to utilize the parallel netcdf functionality we compiled the WRF executable with. From within the `v4.4_bench_conus2.5km` directory, open the `namelist.input` file for writing in an editor of your choice. Modify the input file on lines 24 and 25 to use a parallel writing strategy by changing the value of the `io_form_history` and `io_form_restart` variables from `2` to `11` as shown below.

```bash
io_form_history                     = 11,
io_form_restart                     = 11,
```

Save and close the file once changes are applied. From here, the benchmark is ready to run.

---

## Step 3: Measuring and Recording Performance

Once benchmarking jobs finish successfully, the configured run directories will contain outputs and diagnostic files. Use these files to measure and analyze performance metrics for each test case.

### 3.1: Run the Timing Script

For each of the run directories created above, we will examine the timings reported in the `rsl.error.0000` file. This human-readable file contains lots of valuable information, but we will focus primarily on the execution time. A parsing script, [`get_timing.py`](get_timing.py), is supplied here and can be executed like:

```bash
python get_timing.py --rsl_file=${WRF_DIR}/conus2.5km-mpi-02/rsl.error.0000 --rsl_file=${WRF_DIR}/conus2.5km-mpi-04/rsl.error.0000
```

This script combs through the rsl.error.0000 file(s) specified with the `--rsl_file` flag and extracts the timing results per each step of the algorithm, delineating the steps where file writing was performed since this adds an appreciable amount of time. Note that the `tabulate` package is required to run this script. If it is not already installed in your Python environment, simply do `pip install tabulate`.

---

## Run Definitions and Requirements


Benchmarking WRF requires reporting these timing results from two sets of runs each comprised of 5 test cases for a total of 10 runs. The first set of runs uses pure MPI parallelism (i.e., one OpenMP thread per MPI task) and tests strong scaling performance across 1, 2, 4, 8, and 16 nodes. The Offeror may adjust the total number of MPI tasks, but note that in each case, *at least 80% of the physical cores per every node must be utilized* for baseline submissions. The second set of runs uses hybrid OpenMP + MPI parallelism (i.e., 4 threads per MPI task) and tests strong scaling performance across the same 1, 2, 4, 8, and 16 node jobs. Note that a combination of MPI tasks/threads per task is valid for baseline submissions as long as the total number of physical cores meets or exceeds 80% of available per node. For optimized submissions, any number of physical cores may be used.

For these required cases, report the number of MPI tasks, number of threads, number of iterations during the calculation, total write time, and total time in the reporting spreadsheet (the `get_timing.py` script provides all these outputs). Optionally, the Offeror may include a set of additional "Optimized" cases that use different OpenMP:MPI ratios, node saturations, `namelist.input` specifications, building instructions, etc., provided any details and/or instructions necessary to reproduce these results are provided as explained in the [definition of "Optimized"](../README.md#draft-definitions-for-baselineas-is-ported-and-optimized-runs).

For clarity and comparison, we include the summarized results of carrying out the required benchmarks on the Kestrel HPC below. The output of running the `get_timing.py` script on the 5 `rsl.error.0000` files for the pure MPI tests is:

```
  MPI Tasks    Threads    Iterations    Write Time (s)    Total Time (s)
-----------  ---------  ------------  ----------------  ----------------
         96          1          1440              71.0            7210.9
        192          1          1440              87.4            3768.1
        384          1          1440              64.7            1903.9
        768          1          1440              84.1            1054.7
       1536          1          1440              85.2             574.1
```

The output of running the `get_timing.py` script on the 5 `rsl.error.0000` files for the hybrid OpenMP + MPI tests is:

```
  MPI Tasks    Threads    Iterations    Write Time (s)    Total Time (s)
-----------  ---------  ------------  ----------------  ----------------
         24          4          1440              49.9            6809.0
         48          4          1440              53.6            3526.0
         96          4          1440              38.7            1747.9
        192          4          1440              40.9             888.3
        384          4          1440              46.5             480.4
```

Additionally, the 10x `rsl.error.0000` files necessary to produce these tables are [included here](conus_2.5km/example_outputs/). Visualizing these outputs provides a clearer picture of reasonable scaling performance up to 16 nodes.

![Example timings for the 2.5km benchmark obtained from the Kestrel HPC](conus_2.5km/kestrel_benchmarking_results.png)
*The results for the two sets of required benchmarks obtained on the Kestrel HPC. The plotted values correspond to the "Total Time" columns in the tables above*

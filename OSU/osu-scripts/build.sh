#!/bin/bash


### Example build script for OSU-Benchmarks
### Downloads, configures, and builds OSU Micro-benchmarks 
### SOFTWARE REQUIREMENTS: OpenMPI, MPICH


### Downloads latest version of OSU Micro-benchmarks
wget https://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-7.5-1.tar.gz


## Extracts OSU Micro-benchmarks into working directory

tar -xvzf osu-micro-benchmarks-7.5-1.tar.gz

### Removes tar 
rm osu-micro-benchmarks-7.5-1.tar.gz

### Switches into Micro-benchmark directory
cd osu-micro-benchmarks-7.5-1

### Configures Microbenchmark Installation - installs into 'osu-microbenchmarks-install' directory in parent directory
### We configure using mpicc from MPICH

./configure \
 --prefix=$PWD/../osu-microbenchmarks-install \
 CC=mpicc \
 CXX=mpicxx \

### Makes package then installs into directory specified above
### Single-threaded, add -j option for multithreaded build/install
### Executables will be located in libexec folder in the mpi folder
make
make install 


### Switch out of Micro-benchmark directory
cd ..

### Copy executables into current working directory
cp osu-microbenchmarks-install/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_latency $PWD
cp osu-microbenchmarks-install/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_mbw_mr $PWD
cp osu-microbenchmarks-install/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce $PWD
cp osu-microbenchmarks-install/libexec/osu-micro-benchmarks/mpi/collective/osu_alltoall $PWD
cp osu-microbenchmarks-install/libexec/osu-micro-benchmarks/mpi/collective/osu_bibw $PWD





#!/bin/bash
#SBATCH -N 1
#SBATCH --job-name=osu-pt2pt-bandwidth
#SBATCH --ntasks-per-node=2
#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --output=osu-bandwidth/osu-bandwidth_%a.out
#SBATCH --time=00:20:00
#SBATCH --array=1-5

### Script is written to be submitted to a slurm job scheduler, basic parameters are filled in
### Script can be modified to fit other job schedulers as necessary
### We repeat this test 8 times 
### The purpose of this test is to measure memory bandwidth transfer between CPUs on host device

nodes=1
PPN=2
MSG=65536
TYPE=mpi_float

let RANKS=($nodes * $PPN)

for k in `seq 8`
do
srun  -N $nodes -n $RANKS --ntasks-per-node=$PPN ./osu_bibw -i 5000
done
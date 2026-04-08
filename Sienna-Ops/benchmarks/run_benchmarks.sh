#!/bin/bash
#SBATCH --job-name=sienna
#SBATCH --partition=debug
#SBATCH --time=01:00:00
#SBATCH --account=hpcapps
#SBATCH --nodes=1
#SBATCH --output=slurm_%j.o
#SBATCH --error=slurm_%j.e

# Load required modules
module load julia

JULIA_THREADS=$1

# Set working directory to the benchmarks folder
#cd /scratch/mreynold/ESIFHPC4/Sienna-Ops/benchmarks
cd /projects/hpcapps/isatkaus/msoc-kestrel/sienna-ops/test12/ESIFHPC4/Sienna-Ops/benchmarks

##### test Oprion 2 in clean julia (fresh Project.toml and Manifest.toml)
# backup existing Project.toml and Manifest.toml if they exist
mv Project.toml Project.toml.bak
mv Manifest.toml Manifest.toml.bak

## create temp depo (clean julia environment)  
TMP=$(mktemp -d)

# setup julia environment in that temp depo
echo "installing dependencies in temporary depot at $TMP"
JULIA_DEPOT_PATH="$TMP" julia setup.jl

# run_RTS_UC-ED.jl in that temp depo and capture output
echo "running benchmark in clean julia environment with depot at $TMP"
JULIA_DEPOT_PATH="$TMP" julia --threads=$JULIA_THREADS --project=. run_RTS_UC-ED.jl > rts_RTS_UC-ED.out 2>&1

# cleanup
rm -rf "$TMP"


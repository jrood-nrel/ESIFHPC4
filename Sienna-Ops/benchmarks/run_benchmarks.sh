#!/bin/bash
#SBATCH --job-name=sienna
#SBATCH --partition=debug
#SBATCH --time=01:00:00
#SBATCH --account=hpcapps
#SBATCH --nodes=1
#SBATCH --output=slurm_%j.o
#SBATCH --error=slurm_%j.e

# Load required modules
module load julia/1.12.1

### Julia threads used for running the benchmark (passed as an argument to the script)
JULIA_THREADS=$1

### Set root directory for the benchmark and pull repository (change it as needed)
ROOT_DIR=/projects/hpcapps/isatkaus/msoc-kestrel/sienna-ops/

cd $ROOT_DIR
mkdir test1
cd test1
git clone git@github.com:NatLabRockies/ESIFHPC4.git
cd ESIFHPC4/Sienna-Ops/benchmarks/
#git checkout is/sienna

########### install Option 1
# install recorded environment into temp depot (using Manifest.toml and Project.toml in the repository)
TMP=$(mktemp -d)
JULIA_DEPOT_PATH="$TMP" julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.build()'

### Run run_RTS_UC-ED.jl script 
echo "running benchmark in clean julia environment with depot at $TMP"
JULIA_DEPOT_PATH="$TMP" julia --threads=$JULIA_THREADS --project=. run_RTS_UC-ED.jl > rts_RTS_UC-ED.out 2>&1

# cleanup
rm -rf "$TMP"


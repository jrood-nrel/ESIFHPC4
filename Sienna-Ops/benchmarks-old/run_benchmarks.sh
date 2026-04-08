#!/bin/bash
#SBATCH --job-name=sienna
#SBATCH --partition=debug
#SBATCH --time=01:00:00
#SBATCH --account=hpcapps
#SBATCH --nodes=1
#SBATCH --output=sienna_benchmarks_%j.out
#SBATCH --error=sienna_benchmarks_%j.err

# Load required modules
module load julia

JULIA_THREADS=$1

# Set working directory to the benchmarks folder
cd /scratch/mreynold/ESIFHPC4/Sienna-Ops/benchmarks

# Instantiate the Julia environment
echo "Instantiating Julia environment..."
julia --project=. -e "using Pkg; Pkg.instantiate()"

# Run the benchmark suite
echo "Starting Sienna benchmark..."

echo "Running RTS UC-ED benchmark..."
julia --threads=$JULIA_THREADS --project=. small/run_RTS_UC-ED.jl > fout_RTS_UC-ED_${JULIA_THREADS}.out 2>&1

echo "Benchmark completed!"

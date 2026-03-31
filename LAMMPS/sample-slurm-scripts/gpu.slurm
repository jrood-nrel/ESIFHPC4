#!/bin/bash
#SBATCH --job-name lammps-acceleratednode
#SBATCH --nodes=1
#SBATCH --gres=gpu:4            # Requests 4 GPUs per node
#SBATCH --tasks-per-node=32     # Running 32 MPI tasks per node
#SBATCH --time=00:20:00
#SBATCH --account=hpcapps
#SBATCH --exclusive

# Sample run on NLR's Kestrel machine
# Required for baseline
export OMP_NUM_THREADS=1

module load lammps/072225-gpu

ntasks=$SLURM_NTASKS
tpn=$SLURM_NTASKS_PER_NODE
ngpus=$(($((SLURM_GPUS_ON_NODE))*$((SLURM_NNODES))))
srun --ntasks $ntasks --tasks-per-node=$tpn lmp -sf gpu -pk gpu ${SLURM_GPUS_ON_NODE} -in lammps.in -log lammps-${ngpus}gpus-${SLURM_JOB_ID}.out



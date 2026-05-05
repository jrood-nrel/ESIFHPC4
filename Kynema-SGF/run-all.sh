#!/bin/zsh

set -e

#CPU login node
ssh kl1.hpc.nrel.gov 'bash -s' < kynema-sgf-benchmark-cpu.sh
ssh kl1.hpc.nrel.gov 'bash -s' < kynema-sgf-benchmark-cpu-verify.sh

#GPU login node
ssh kl5.hpc.nrel.gov 'bash -s' < kynema-sgf-benchmark-gpu.sh
ssh kl5.hpc.nrel.gov 'bash -s' < kynema-sgf-benchmark-gpu-aware.sh
ssh kl5.hpc.nrel.gov 'bash -s' < kynema-sgf-benchmark-gpu-verify.sh

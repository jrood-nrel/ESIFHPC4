#!/bin/bash

# Commands that gather all NLR results from the sample output files

# First print the standard node results
./collect-perf-results.py small/NLR-results/std-1nodes.out small/NLR-results/std-2nodes.out small/NLR-results/std-4nodes.out medium/NLR-results/std-1nodes.out medium/NLR-results/std-2nodes.out medium/NLR-results/std-4nodes.out large/NLR-results/std-4nodes.out large/NLR-results/std-8nodes.out

# Next print the accelerated node results
./collect-perf-results.py small/NLR-results/accel-4gpus.out small/NLR-results/accel-8gpus.out medium/NLR-results/accel-4gpus.out medium/NLR-results/accel-8gpus.out medium/NLR-results/accel-16gpus.out medium/NLR-results/accel-32gpus.out large/NLR-results/accel-32gpus.out large/NLR-results/accel-48gpus.out large/NLR-results/accel-64gpus.out


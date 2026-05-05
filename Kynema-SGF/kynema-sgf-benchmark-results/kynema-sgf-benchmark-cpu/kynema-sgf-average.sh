#!/bin/bash

set -e

i=1
for file in $(ls -d1 kynema-sgf-benchmark* | sort -V); do
    echo "$file"
    grep ^WallClockTime "$file" | awk '{print $NF}' > kynema-sgf-time-$i.txt
    python3 kynema-sgf-average.py -f kynema-sgf-time-$i.txt >> kynema-sgf-avg.txt
    rm kynema-sgf-time-$i.txt
    ((i=i+1))
done

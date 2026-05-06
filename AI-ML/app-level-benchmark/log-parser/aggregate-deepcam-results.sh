#!/bin/bash

# Run this after parsing and validating all requested DeepCAM runs.

# Scenario 1
scen1_header=$(cat *Scenario1.csv | head -n 1)
echo $scen1_header > Scenario1_ReportingTable.csv
cat *Scenario1.csv | grep -v $scen1_header >> Scenario1_ReportingTable.csv

# Scenario 2
scen2_header=$(cat *Scenario2.csv | head -n 1)
echo $scen2_header > Scenario2_ReportingTable.csv
cat *Scenario2.csv | grep -v $scen2_header >> Scenario2_ReportingTable.csv
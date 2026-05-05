# GPU stream benchmark


## Purpose

Stream.cu and mstream.cu are GPU versions of the classic stream.c benchmark.
Stream.cu is a slight variation of the code from 

  https://github.com/bcumming/cuda-stream

Mstream.cu adds MPI to enable running stream across all GPUs on a node in 
parallel.  It normally would be run with the number of tasks on a node equal
to the number of GPUs on the node.


## Build and run cuda versions...

The included makefile shows the build process of the two codes.  Stream.cu
can be built with the "normal" nvcc.  Mstream.cu requires a mpicc that also
supports cuda.  

The number of iterations run can be set sith a compile line option.  For example

```
-DNTIMES=1000

```

Both codes take a runtime option, -n,  specifying the size of the arrays.  The size
should be chosen to fill the GPU memory to at least 75%.

Since mstream is a MPI program it is run using srun.  It should be run with the number
of tasks per node equal to the number of GPUs per node.

Mstream will produce a output file for each task strm.xxxx It also sends intermediate 
timings to stdout.  This is for debug pruposes only and is not normally important.

The file runit has typical command for running the two codes.  Note that in this case
-n is actually much smaller than required to fill the GPUs.  From runit...

```
	make mstream
	srun --tasks-per-node=4  --nodes=2 --tasks=8 ./mstream -n 5000 > mstream.out
	make stream
	./stream -n 5000 > stream.out
```

Stream.cu also takes a command line argument -g which it the target gpu.  This should not
normally be used for mstream.cu.

## Reporting requirements.  

Run mstream for N tasks per node where N is the number of GPUs on a node with the size
of the arrays filling 75% of the memory on the GPUs.  Provide all build and run scripts,
any code modifications and the files strm.xxxx 


The following is partial output from the programs:

```


[tkaiser2@kl5 pstream]$cat stream.out
 STREAM Benchmark implementation in CUDA on device 0 of x3103c0s25b0n0
 Device name: NVIDIA H100 80GB HBM3
 Array elements 5000 Array size (double precision) =    0.040000 MB
 Total memory for 3 arrays =    0.000120 GB
 NTIMES 200000
 using 192 threads per block, 27 blocks
 output in IEC units (KiB = 1024 B)

Function      Rate (GiB/s)  Avg time(s)  Min time(s)  Max time(s)
-----------------------------------------------------------------
Copy:          10.7759      0.00000725   0.00000691   0.00003815
Scale:         12.5000      0.00000721   0.00000596   0.00003600
Add:           18.7500      0.00000720   0.00000596   0.00003314
Triad:         18.7500      0.00000722   0.00000596   0.00002909
 Total time      5.805 seconds
[tkaiser2@kl5 pstream]$
[tkaiser2@kl5 pstream]$
[tkaiser2@kl5 pstream]$
[tkaiser2@kl5 pstream]$ls strm.0*
strm.0000  strm.0001  strm.0002  strm.0003  strm.0004  strm.0005  strm.0006  strm.0007
[tkaiser2@kl5 pstream]$
[tkaiser2@kl5 pstream]$
[tkaiser2@kl5 pstream]$
[tkaiser2@kl5 pstream]$cat strm.0000
 STREAM Benchmark implementation in CUDA on device 0 of x3103c0s25b0n0
 Device name: NVIDIA H100 80GB HBM3
 Array elements 5000 Array size (double precision) =    0.040000 MB
 Total memory for 3 arrays =    0.000120 GB
 NTIMES 1000
 using 192 threads per block, 27 blocks
 output in IEC units (KiB = 1024 B)

Function      Rate (GiB/s)  Avg time(s)  Min time(s)  Max time(s)
-----------------------------------------------------------------
Copy:          10.7759      0.00000740   0.00000691   0.00001407
Scale:         10.7759      0.00000738   0.00000691   0.00001287
Add:           16.1638      0.00000736   0.00000691   0.00001907
Triad:         16.1638      0.00000736   0.00000691   0.00001907
 Total time       0.03 seconds
[tkaiser2@kl5 pstream]$
[tkaiser2@kl5 pstream]$
[tkaiser2@kl5 pstream]$
[tkaiser2@kl5 pstream]$cat strm.0007
 STREAM Benchmark implementation in CUDA on device 3 of x3106c0s21b0n0
 Device name: NVIDIA H100 80GB HBM3
 Array elements 5000 Array size (double precision) =    0.040000 MB
 Total memory for 3 arrays =    0.000120 GB
 NTIMES 1000
 using 192 threads per block, 27 blocks
 output in IEC units (KiB = 1024 B)

Function      Rate (GiB/s)  Avg time(s)  Min time(s)  Max time(s)
-----------------------------------------------------------------
Copy:          10.7759      0.00000724   0.00000691   0.00001216
Scale:         12.5000      0.00000726   0.00000596   0.00007105
Add:           16.1638      0.00000719   0.00000691   0.00001121
Triad:         16.1638      0.00000730   0.00000691   0.00001383
 Total time       0.03 seconds
[tkaiser2@kl5 pstream]$


```

If the vendor runs the GPU/MPI enabled version of stream a file similar to
test-run/cpu.out should be provided.  This is a report of the rates for the
various tests on each node and GPU on the node. This is a summary of the strm.\*
files.

NODE,GPU,Copy,Scale,Add,Triad
x3104c0s17b0n0,0,10.7759,10.7759,16.1638,16.1638
x3104c0s17b0n0,1,10.7759,10.7759,16.1638,16.1638
x3104c0s17b0n0,2,10.7759,10.7759,16.1638,16.1638
x3104c0s17b0n0,3,12.5000,12.5000,18.7500,18.7500
x3104c0s21b0n0,0,10.7759,10.7759,16.1638,16.1638
x3104c0s21b0n0,1,10.7759,10.7759,16.1638,16.1638
x3104c0s21b0n0,2,10.7759,10.7759,16.1638,16.1638
x3104c0s21b0n0,3,10.7759,10.7759,16.1638,16.1638


## Hip versions
Mstream.hip and stream.hip are hip versions of the codes.  These can be built 
with the script dohip.







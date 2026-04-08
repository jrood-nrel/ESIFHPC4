using PowerSystems
using PowerSimulations
using HydroPowerSimulations
const PSI = PowerSimulations
const PSY = PowerSystems
using PowerSystemCaseBuilder
using Dates
using CSV
using DataFrames
using Logging
using BenchmarkTools
using Ipopt #solver
using HiGHS

# Setup benchmark output directory
benchmark_output_dir = joinpath(@__DIR__, "benchmark_results")
mkpath(benchmark_output_dir)
benchmark_name = "RTS_UC_ED"

function create_templates()
    template_uc = template_unit_commitment(
        network = NetworkModel(DCPPowerModel; use_slacks = true);
        use_slacks = false
    )
    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)

    template_ed = template_economic_dispatch(;
        network = NetworkModel(DCPPowerModel; use_slacks = true),
    )
    set_device_model!(template_ed, ThermalStandard, ThermalDispatchNoMin)
    set_device_model!(template_ed, TwoTerminalHVDCLine, HVDCTwoTerminalLossless)
    
    return template_uc, template_ed
end

function create_simulation_model(
    template_uc::PSI.ProblemTemplate,
    template_ed::PSI.ProblemTemplate,
    sys_DA::PSY.System,
    sys_RT::PSY.System,
    solver_UC::PSI.MathOptInterface.OptimizerWithAttributes,
    solver_ED::PSI.MathOptInterface.OptimizerWithAttributes
)
    models = SimulationModels(;
        decision_models = [
            DecisionModel(
                template_uc,
                sys_DA;
                optimizer = solver_UC,
                name = "UC",
                optimizer_solve_log_print = true
            ),
            DecisionModel(template_ed, sys_RT; optimizer = solver_ED, name = "ED",),
        ],
    )

    feedforward = Dict(
        "ED" => [
            SemiContinuousFeedforward(;
                component_type = ThermalStandard,
                source = OnVariable,
                affected_values = [ActivePowerVariable],
            ),
        ],
    )

    DA_RT_sequence = SimulationSequence(;
        models = models,
        ini_cond_chronology = InterProblemChronology(),
        feedforwards = feedforward,
    )

    # Create simulation output directory if it doesn't exist
    isdir("RTS-store") || mkdir("RTS-store")

    sim = Simulation(;
        name = "rts-test",
        steps = 1,
        models = models,
        sequence = DA_RT_sequence,
        simulation_folder = "RTS-store",
    )
    
    return sim
end

function benchmark_build_and_execute(
    template_uc::PSI.ProblemTemplate,
    template_ed::PSI.ProblemTemplate,
    sys_DA::PSY.System,
    sys_RT::PSY.System,
    solver_UC::PSI.MathOptInterface.OptimizerWithAttributes,
    solver_ED::PSI.MathOptInterface.OptimizerWithAttributes
)
    # Create a fresh simulation for each benchmark run
    fresh_sim = create_simulation_model(template_uc, template_ed, sys_DA, sys_RT, solver_UC, solver_ED)
    build!(
        fresh_sim,
        console_level=Logging.Info,
        file_level=Logging.Debug
    )
    execute!(fresh_sim; enable_progress_bar = true)
    return fresh_sim
end

function analyze_results(s::PSI.Simulation)
    results = SimulationResults(s)
    uc_results = get_decision_problem_results(results, "UC") # UC stage result metadata
    ed_results = get_decision_problem_results(results, "ED") # ED stage result metadata
    
    read_variables(uc_results)
    read_parameters(uc_results)
    
    return (results=results, uc_results=uc_results, ed_results=ed_results)
end

function generate_benchmark_report(
    timing_summary::DataFrame, 
    samples::Int,
    max_time_seconds::Int,
    output_dir::String,
    benchmark_name::String
)
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    
    # Save CSV file
    CSV.write(joinpath(output_dir, "$(benchmark_name)_timing_$(timestamp).csv"), timing_summary)
    
    # Create benchmark summary report
    summary_file = joinpath(output_dir, "$(benchmark_name)_summary_$(timestamp).txt")
    open(summary_file, "w") do io
        println(io, "# PowerSimulations.jl Benchmark Summary - RTS UC-ED")
        println(io, "Run date: $(now())")
        println(io, "")
        println(io, "## System Information")
        println(io, "Julia version: $(VERSION)")
        println(io, "CPU model: $(Sys.cpu_info()[1].model)")
        println(io, "CPU cores: $(Sys.CPU_THREADS)")
        println(io, "Total memory: $(round(Sys.total_memory() / 1024^3, digits=2)) GB")
        println(io, "")
        println(io, "## Benchmark Configuration")
        println(io, "Samples per benchmark: $samples")
        println(io, "Max time per benchmark: $max_time_seconds seconds")
        println(io, "")
        println(io, "## Benchmark Results")
        println(io, "")
        println(io, "### Execution Time (seconds)")
        for row in eachrow(timing_summary)
            println(io, "- $(row.component): $(round(row.time_seconds, digits=4))")
        end
        println(io, "- Total: $(round(sum(timing_summary.time_seconds), digits=4))")
        println(io, "")
        println(io, "### Memory Usage")
        for row in eachrow(timing_summary)
            if row.memory_bytes > 0
                println(io, "- $(row.component): $(round(row.memory_bytes / 1024^2, digits=2)) MB")
            end
        end
        println(io, "")
        println(io, "### Allocations")
        for row in eachrow(timing_summary)
            if row.allocations > 0
                println(io, "- $(row.component): $(row.allocations) allocations")
            end
        end
    end
    
    return (csv_file = joinpath(output_dir, "$(benchmark_name)_timing_$(timestamp).csv"),
            summary_file = summary_file,
            timestamp = timestamp)
end

# Create a wrapper function to benchmark
function run_benchmark(;
    samples = 1,  # Number of samples for all benchmarks
    max_time_seconds = 300  # Maximum time to spend on each benchmark
)
    # Setup solvers
    solver_UC = optimizer_with_attributes(
        HiGHS.Optimizer, 
        "mip_rel_gap" => 0.01, 
        "log_to_console" => true,
        "output_flag" => true,
        "parallel" => "on",
    )
    solver_ED = optimizer_with_attributes(
        Ipopt.Optimizer,
        # "linear_solver" => "ma27",
        "print_level" => 3,
        "tol" => 1e-6,
        "acceptable_tol" => 1.e-4,
    )
    
    # Benchmark system loading
    @info "Benchmarking system loading..."
    load_da_system_func() = build_system(PSISystems, "modified_RTS_GMLC_DA_sys"; skip_serialization = true)
    load_rt_system_func() = build_system(PSISystems, "modified_RTS_GMLC_RT_sys"; skip_serialization = true)
    
    da_system_load_bench = @benchmark $load_da_system_func() samples=samples evals=1 seconds=max_time_seconds 
    rt_system_load_bench = @benchmark $load_rt_system_func() samples=samples evals=1 seconds=max_time_seconds 
    
    da_system_load_time = minimum(da_system_load_bench.times) / 1e9
    rt_system_load_time = minimum(rt_system_load_bench.times) / 1e9
    
    sys_DA = load_da_system_func()  # Get the actual result
    sys_RT = load_rt_system_func()  # Get the actual result
    
    # Benchmark template creation
    @info "Benchmarking template creation..."
    template_creation_bench = @benchmark $create_templates() samples=samples evals=1 seconds=max_time_seconds
    template_creation_time = minimum(template_creation_bench.times) / 1e9
    
    template_uc, template_ed = create_templates()  # Get the actual result

    # Benchmark model creation
    @info "Benchmarking Simulation model creation..."
    model_creation_bench = @benchmark $create_simulation_model($template_uc, $template_ed, $sys_DA, $sys_RT, $solver_UC, $solver_ED) samples=samples evals=1 seconds=max_time_seconds
    model_creation_time = minimum(model_creation_bench.times) / 1e9
    
    sim = create_simulation_model(template_uc, template_ed, sys_DA, sys_RT, solver_UC, solver_ED)  # Get the actual result

    # Benchmark build and execute together
    @info "Benchmarking build and execute phases..."    
    build_execute_bench = @benchmark $benchmark_build_and_execute($template_uc, $template_ed, $sys_DA, $sys_RT, $solver_UC, $solver_ED) samples=samples evals=1 seconds=max_time_seconds
    build_execute_time = minimum(build_execute_bench.times) / 1e9
    
    # Run build and execute once for the main simulation for results analysis
    sim = benchmark_build_and_execute(template_uc, template_ed, sys_DA, sys_RT, solver_UC, solver_ED)
    
    # Analyze results
    @info "Analyzing results..."
    analysis_results = analyze_results(sim)
    results = analysis_results.results
    
    # Create timing summary
    timing_summary = DataFrame(
        component = ["DA System Loading", "RT System Loading", "Template Creation", 
                   "Model Creation", "Build+Execute"],
        time_seconds = [da_system_load_time, rt_system_load_time, template_creation_time,
                       model_creation_time, build_execute_time],
        memory_bytes = [
            da_system_load_bench.memory,
            rt_system_load_bench.memory,
            template_creation_bench.memory,
            model_creation_bench.memory,
            build_execute_bench.memory,
        ],
        allocations = [
            da_system_load_bench.allocs,
            rt_system_load_bench.allocs,
            template_creation_bench.allocs,
            model_creation_bench.allocs,
            build_execute_bench.allocs,
        ]
    )
    
    # Generate reports
    report_files = generate_benchmark_report(timing_summary, samples, max_time_seconds, 
                                            benchmark_output_dir, benchmark_name)
    
    # Return results
    return Dict(
        "sim" => sim,
        "results" => results,
        "timing" => timing_summary,
        "report_files" => report_files,
        "benchmarks" => Dict(
            "da_system_load" => da_system_load_bench,
            "rt_system_load" => rt_system_load_bench,
            "template_creation" => template_creation_bench,
            "model_creation" => model_creation_bench,
            "build_execute" => build_execute_bench,
        )
    )
end

# Run the benchmark with default settings
@info "Starting benchmark for RTS_UC_ED"
benchmark_results = run_benchmark()

# Alternative: Run with faster testing (fewer samples)
# benchmark_results = run_benchmark(samples = 1, max_time_seconds = 60)

# Alternative: Run with high accuracy (more samples)
# benchmark_results = run_benchmark(samples = 10, max_time_seconds = 600)

@info "Benchmark completed and saved to $(benchmark_output_dir)"

# Extract sim and results for compatibility
sim = benchmark_results["sim"]
results = benchmark_results["results"]

# Print summary of results
println("\nBenchmark Summary:")
println("=================")
println("Component\t\tTime (s)\tMemory (MB)\tAllocations")
for row in eachrow(benchmark_results["timing"])
    memory_mb = row.memory_bytes > 0 ? round(row.memory_bytes / 1024^2, digits=2) : "N/A"
    allocs = row.allocations > 0 ? string(row.allocations) : "N/A"
    println("$(rpad(row.component, 16))\t$(round(row.time_seconds, digits=4))\t\t$(memory_mb)\t\t$(allocs)")
end
println("$(rpad("Total", 16))\t$(round(sum(benchmark_results["timing"].time_seconds), digits=4))")
println("\nDetailed results saved to: $(benchmark_output_dir)")

# Example usage with different sample counts:
# 
# Quick test run (1 sample per benchmark):
# run_benchmark(samples=1)
#
# Default run (3 samples per benchmark, good balance of accuracy and speed):
# run_benchmark(samples=3)
#
# High accuracy run (10 samples per benchmark):
# run_benchmark(samples=10)
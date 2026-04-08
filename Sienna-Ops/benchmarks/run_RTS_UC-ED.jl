using PowerSystems
using PowerSimulations
using HydroPowerSimulations
const PSI = PowerSimulations
const PSY = PowerSystems
using PowerSystemCaseBuilder
using PowerGraphics
using PowerAnalytics
using Logging
using Printf
using Ipopt
using HiGHS

# ── Solvers ───────────────────────────────────────────────────────────────────
solver_UC = optimizer_with_attributes(
    HiGHS.Optimizer,
    "mip_rel_gap" => 0.02,
    "log_to_console" => true,
    "output_flag" => true,
    "parallel" => "on",
    "random_seed" => 25,
)
solver_ED = optimizer_with_attributes(
    Ipopt.Optimizer,
    "print_level" => 3,
    "tol" => 1e-6,
    "acceptable_tol" => 1e-4,
)

t_script_start = time()

# ── Load systems ──────────────────────────────────────────────────────────────
@info "Loading systems..."
t0 = time()
sys_DA = build_system(PSISystems, "modified_RTS_GMLC_DA_sys"; skip_serialization = true)
sys_RT = build_system(PSISystems, "modified_RTS_GMLC_RT_sys"; skip_serialization = true)
# PSCB 2.2.1 bug: in PSY5, SynchronousCondenser is no longer <: Generator so
# the PSCB removal loop silently skips these units. Remove them explicitly.
for sys in (sys_DA, sys_RT)
    for d in collect(PSY.get_components(PSY.SynchronousCondenser, sys))
        PSY.remove_component!(sys, d)
    end
end
t_load = time() - t0

# ── Templates ─────────────────────────────────────────────────────────────────
template_uc = template_unit_commitment(
    network = NetworkModel(DCPPowerModel; use_slacks = true);
    use_slacks = false,
)
set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)

template_ed = template_economic_dispatch(;
    network = NetworkModel(DCPPowerModel; use_slacks = true),
)

set_device_model!(template_ed, ThermalStandard, ThermalDispatchNoMin)
# Override default HVDCTwoTerminalDispatch (has binary direction var → Ipopt fails)
# with HVDCTwoTerminalLossless (no binaries) so ED stays LP-solvable with Ipopt.
# # old (0.30 / PSY4)
# set_device_model!(template_ed, TwoTerminalHVDCLine, HVDCTwoTerminalLossless)
# new (0.31+ / PSY5)
set_device_model!(template_ed, DeviceModel(TwoTerminalGenericHVDCLine, HVDCTwoTerminalLossless))


# ── Simulation ────────────────────────────────────────────────────────────────
models = SimulationModels(;
    decision_models = [
        DecisionModel(
            template_uc,
            sys_DA;
            optimizer = solver_UC,
            name = "UC",
            optimizer_solve_log_print = true,
        ),
        DecisionModel(template_ed, sys_RT; optimizer = solver_ED, name = "ED"),
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

isdir("RTS-store") || mkdir("RTS-store")

sim = Simulation(;
    name = "rts-test",
    steps = 2,
    models = models,
    sequence = DA_RT_sequence,
    simulation_folder = "RTS-store",
)

# ── Build & execute ───────────────────────────────────────────────────────────
@info "Building simulation..."
t0 = time()
build!(sim; console_level = Logging.Info, file_level = Logging.Debug)
t_build = time() - t0

@info "Executing simulation..."
t0 = time()
execute!(sim; enable_progress_bar = true)
t_execute = time() - t0

t_total = time() - t_script_start
@info "\n── Timing summary ───────────────────────────────────────────────────────────"
@info @sprintf("  Systems loaded : %6.1f s", t_load)
@info @sprintf("  Build          : %6.1f s", t_build)
@info @sprintf("  Execute        : %6.1f s", t_execute)
@info @sprintf("  Total          : %6.1f s  (%.1f min)", t_total, t_total / 60)


# ── Parse results & save fuel plots ──────────────────────────────────────────
# Suppress GR "cannot open display" warning on headless nodes
ENV["GKSwstype"] = "100"

function parse_results(sim)
    results    = SimulationResults(sim)
    uc_results = get_decision_problem_results(results, "UC")
    ed_results = get_decision_problem_results(results, "ED")

    store_dir    = results.path
    run_name     = basename(store_dir)
    plot_dir     = joinpath(dirname(dirname(store_dir)), "RTS-plots", run_name)
    mkpath(plot_dir)

    for (res, label) in [(uc_results, "UC"), (ed_results, "ED")]
        try
            plot_fuel(res; title = label, save = plot_dir, set_display = false)
        catch e
            @error "plot_fuel failed for $label" exception = (e, catch_backtrace())
        end
    end

    return uc_results, ed_results, run_name
end

uc_results, ed_results, run_name = parse_results(sim)

@info "Simulation results saved to: $(joinpath("RTS-store", run_name))"
@info "Plots saved to:           $(joinpath("RTS-plots", run_name))"


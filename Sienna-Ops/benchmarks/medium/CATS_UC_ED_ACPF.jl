using AppleAccelerate
using PowerSystems
using PowerSimulations
using HydroPowerSimulations
using PowerSystemCaseBuilder
# using HiGHS # solver
using Ipopt
using Dates
using JuMP
using PowerFlows
import PowerNetworkMatrices: VirtualPTDF, PTDF
import InfrastructureSystems

const PSY = PowerSystems
const PSI = PowerSimulations

import Xpress

import HSL_jll # works only after getting the HSL license and the files for HSL_jll
using HSL # works only after getting the HSL license and the files for HSL_jll (]dev HSL_jll first)

function check_impedances!(
    system::PSY.System, 
    min_ohm_line::Float64=0.1, 
    max_ohm_line::Float64=150.,
    rx_line::Float64=0.25,
    min_ohm_tr2::Float64=0.1,
    max_ohm_tr2::Float64=15., 
    rx_tr2::Float64=0.1
)
    base_mva = get_base_power(system)
    lines = get_components(Line, system)
    tr2w = get_components(Transformer2W, system)
    for (branches, min_ohm, max_ohm, rx) in zip((lines, tr2w), (min_ohm_line, min_ohm_tr2), (max_ohm_line, max_ohm_tr2), (rx_line, rx_tr2))
        for br in branches
            vn_kv = get_base_voltage(get_from(get_arc(br)))
            base_z = vn_kv^2 / base_mva
            r_ohm = get_r(br) * base_z
            x_ohm = get_x(br) * base_z
            # R does not matter except when it is too high
            if x_ohm < min_ohm 
                @warn "$(typeof(br)) $(get_name(br)) has a very low reactance: $(x_ohm) Ohm"
                new_x_pu = min_ohm / base_z
                set_x!(br, new_x_pu)
                new_r_pu = rx * new_x_pu
                set_r!(br, new_r_pu)
            elseif x_ohm > max_ohm
                @warn "$(typeof(br)) $(get_name(br)) has a very high reactance: $(x_ohm) Ohm"
                new_x_pu = max_ohm / base_z
                set_x!(br, new_x_pu)
                new_r_pu = rx * new_x_pu
                set_r!(br, new_r_pu)
            end
            if r_ohm > max_ohm
                @warn "$(typeof(br)) $(get_name(br)) has a very high resistance: $(r_ohm) Ohm"
                new_r_pu = rx * x_ohm / base_z
                set_r!(br, new_r_pu)
            end
        end
    end
end

function set_tight_voltage_limits!(system::PSY.System)
    buses = get_components(ACBus, system)
    for b in buses
        if get_bustype(b) ∈ (ACBusTypes.REF, ACBusTypes.PV)
            set_voltage_limits!(b, (min = 0.99, max = 1.01))
            set_magnitude!(b, 1.0)
        end
    end
end

function transform_ts!(system::PSY.System, system_ed::PSY.System)
    transform_single_time_series!(
           system,
           Dates.Hour(HORIZON_UC),  # horizon: 48 hr ahead 
           Dates.Hour(1),   # interval 
       );

    transform_single_time_series!(
        system_ed,
        Dates.Hour(HORIZON_ED),  # horizon: 1 hr ahead
        Dates.Hour(1),  # interval 
    );
end

function setup_uc_problem(
    system::PSY.System,
    ac_pf::Bool,
    ds::Bool,
    q_lim::Bool,
)
    ptdf = VirtualPTDF(system;
        tol = V_PTDF_TOL,
        max_cache_size = 10000,
        # radial_network_reduction = RadialNetworkReduction(PNM.IncidenceMatrix(sys)), #Jose's idea
        )
    network_model_uc = nothing
    if ac_pf
        # network_model_uc = NetworkModel(PTDFPowerModel; PTDF_matrix=ptdf, power_flow_evaluation=PowerFlows.ACPowerFlow(;calculate_loss_factors=true, generator_slack_participation_factors=Dict(get_name(x) => 1.0 for x in get_components(Generator, system))))
        if ds
            network_model_uc = NetworkModel(
                PTDFPowerModel; 
                # PTDF_matrix=ptdf,
                # use_slacks=true, 
                power_flow_evaluation=PowerFlows.ACPowerFlow(
                    ;
                    calculate_loss_factors=true, 
                    # generator_slack_participation_factors=Dict((typeof(x), get_name(x)) => 1.0 for x in get_components(Generator, system)),
                    check_reactive_power_limits=q_lim,
                )
            )
        else
            network_model_uc = NetworkModel(
                PTDFPowerModel; 
                # PTDF_matrix=ptdf,
                # use_slacks=true, 
                power_flow_evaluation=PowerFlows.ACPowerFlow(
                    ;
                    calculate_loss_factors=true,
                    check_reactive_power_limits=q_lim,
                )
             )
        end
    else
        # network_model_uc = NetworkModel(PTDFPowerModel; PTDF_matrix=ptdf, use_slacks=true, )
        # network_model_uc = NetworkModel(PTDFPowerModel, PTDF_matrix=ptdf)
        network_model_uc = NetworkModel(PTDFPowerModel)
    end

    template_uc = ProblemTemplate(network_model_uc)
    set_device_model!(template_uc, ThermalStandard, ThermalBasicUnitCommitment)
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
    set_device_model!(template_uc, Line, StaticBranch)
    # set_device_model!(template_uc, Transformer2W, StaticBranch)
    # set_device_model!(template_uc, DeviceModel(Line, StaticBranch; attributes = Dict("filter_function" => x -> get_base_voltage(get_from(get_arc(x))) > 100)))
    # set_device_model!(template_uc, DeviceModel(Transformer2W, StaticBranch; attributes = Dict("filter_function" => x -> get_base_voltage(get_to(get_arc(x))) > 300)))

    solver_xpress = JuMP.optimizer_with_attributes(
        Xpress.Optimizer,
        "MIPRELSTOP" => 0.2
    )

    problem_uc = DecisionModel(
    template_uc, 
    system; 
    optimizer = solver_xpress, 
    optimizer_solve_log_print = true, 
    name = "UC"
    )

    return problem_uc
end

function setup_ed_problem(system::PSY.System, ds::Bool, q_lim::Bool)
    network_model_ed = NetworkModel(
        ACPPowerModel; 
        use_slacks=false, 
        # power_flow_evaluation=PowerFlows.ACPowerFlow(
        #     ;
        #     calculate_loss_factors=true, 
        #     check_reactive_power_limits=q_lim,
        #     # generator_slack_participation_factors=ds ? Dict(get_name(x) => 1.0 for x in get_components(Generator, system)) : nothing,
        # ),
    )

    template_ed = ProblemTemplate(network_model_ed)
    set_device_model!(template_ed, ThermalStandard, ThermalBasicDispatch)
    set_device_model!(template_ed, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_ed, HydroDispatch, HydroDispatchRunOfRiver)
    set_device_model!(template_ed, PowerLoad, StaticPowerLoad)
    set_device_model!(template_ed, Line, StaticBranchUnbounded)
    set_device_model!(template_ed, Transformer2W, StaticBranchUnbounded)

    solver_ipopt = JuMP.optimizer_with_attributes(Ipopt.Optimizer,
    "print_level" => 5,
    "hsllib" => HSL_jll.libhsl_path, # uncomment after getting the HSL license and the files for HSL_jll
    "linear_solver" => "ma97", # uncomment after getting the HSL license and the files for HSL_jll
    "tol" => 1e-6,
    "acceptable_tol" => 1e-3,
    )

    problem_ed = DecisionModel(
    template_ed, 
    system; 
    optimizer = solver_ipopt,
    optimizer_solve_log_print = true, 
    name = "ED")

    return problem_ed
end

function setup_simulation(problem_uc, problem_ed)
    models = SimulationModels(;
        decision_models = [
            problem_uc,
            problem_ed,
        ],
    )

    sequence = SimulationSequence(;
        models = models,
        feedforwards = Dict(
            "ED" => [
                SemiContinuousFeedforward(;
                    component_type = ThermalStandard,
                    source = OnVariable,
                    affected_values = [ActivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology = InterProblemChronology(),
    )

    sim = Simulation(;
        name = "no_cache",
        steps = 2,
        models = models,
        sequence = sequence,
        simulation_folder = mktempdir(),
    )

    return sim
end

function build_execute_problem!(problem)
    build_out = build!(problem; output_dir = mktempdir())
    @assert build_out == InfrastructureSystems.Optimization.ModelBuildStatusModule.ModelBuildStatus.BUILT
    solve_out = solve!(problem)
    @assert solve_out == InfrastructureSystems.Simulation.RunStatusModule.RunStatus.SUCCESSFULLY_FINALIZED
end

function build_execute_sim!(sim)
    build_out = build!(sim)
    @assert build_out == PSI.SimulationBuildStatus.BUILT

    exports = Dict(
        "models" => [
            Dict(
                "name" => "UC",
                "store_all_variables" => true,
                "store_all_parameters" => true,
                "store_all_duals" => true,
                "store_all_aux_variables" => true,
            ),
            Dict(
                "name" => "ED",
                "store_all_variables" => true,
                "store_all_parameters" => true,
                "store_all_duals" => true,
                "store_all_aux_variables" => true,
            ),
        ],
        "path" => mktempdir(),
        "optimizer_stats" => true,
    )
    execute_out = execute!(sim; exports = exports, in_memory = true)
    @assert execute_out == PSI.RunStatus.SUCCESSFULLY_FINALIZED

end

function get_uc_ed_results(sim)
    results = SimulationResults(sim);
    uc_results = get_decision_problem_results(results, "UC")
    ed_results = get_decision_problem_results(results, "ED")
    return uc_results, ed_results
end


function get_q_slacks(vd, cutoff=0.1)
    qsl_up = collect(first(first(vd["SystemBalanceSlackUp__ACBus__Q"])[2])[2:end])
    qsl_down = collect(first(first(vd["SystemBalanceSlackDown__ACBus__Q"])[2])[2:end])
    return (qsl_up .> cutoff) .| (qsl_down .> cutoff)
end


function sc_add_simple(system, vd)
    q_sl = get_q_slacks(vd)
    buses = get_components(ACBus, system)
    for (b, q) in zip(collect(buses), q_sl)
        if q
            t = ThermalStandard(
                "SC_$(get_name(b))", 
                true, 
                true,
                b,
                0,
                0,
                100,
                (min=0, max=0),
                (min=-1000, max=1000), 
                nothing, 
                ThermalGenerationCost(variable = zero(CostCurve), fixed = 10.0, start_up = 0.0, shut_down = 0.0,),
                100,
                nothing,
                false,
                PrimeMovers.OT
            )
            # t = FixedAdmittance("SC_$(get_name(b))", true, b, 0 + 0.1im)
            add_component!(system, t)
            @show get_name(t)
            if get_bustype(b) == ACBusTypes.PQ
                @show get_name(b)
                set_bustype!(b, ACBusTypes.PV)
            end
        end
    end
end


##############################

UC_ONLY = false
DIST_SLACK = true
Q_LIMITS = true
V_PTDF_TOL = eps()  # defaults to eps()
V_PTDF_CACHESIZE = 1e5
HORIZON_UC = Hour(6)
HORIZON_ED = Hour(6)

system_path = joinpath(@__DIR__, "input_data", "CATS", "sys.json")
system = PSY.System(system_path)
system_ed = deepcopy(system)

set_tight_voltage_limits!(system_ed)

transform_ts!(system, system_ed)

uc_results, ed_results, vd, ad = nothing, nothing, nothing, nothing

if UC_ONLY
    problem_uc = setup_uc_problem(system, false, DIST_SLACK, Q_LIMITS)
    # @show problem_uc
    build_execute_problem!(problem_uc)
    uc_results = OptimizationProblemResults(problem_uc)
    ed_results = nothing
    vd = read_variables(uc_results)
    ad = read_aux_variables(uc_results)

    # @show maximum(ad["PowerFlowVoltageMagnitude__ACBus"][1, 2:end])
    # @show minimum(ad["PowerFlowVoltageMagnitude__ACBus"][1, 2:end])
else
    problem_uc = setup_uc_problem(system, false, DIST_SLACK, Q_LIMITS)
    problem_ed = setup_ed_problem(system_ed, DIST_SLACK, Q_LIMITS)
    # @show problem_uc
    # @show problem_ed
    sim = setup_simulation(problem_uc, problem_ed)
    @show sim
    build_execute_sim!(sim)
    uc_results, ed_results = get_uc_ed_results(sim)
    vd = read_variables(ed_results)
    ad = read_aux_variables(ed_results)

    # @show maximum(collect(first((first(vd["SystemBalanceSlackUp__ACBus__Q"])[2]))[2:end]))

    # @show maximum(collect(first((first(vd["SystemBalanceSlackDown__ACBus__Q"])[2]))[2:end]))

    # @show maximum(collect(first((first(vd["SystemBalanceSlackUp__ACBus__P"])[2]))[2:end]))

    # @show maximum(collect(first((first(vd["SystemBalanceSlackDown__ACBus__P"])[2]))[2:end]))

    # sc_add_simple(system_ed, vd)
end

# lf_res=ad["PowerFlowLossFactors__ACBus"]







# function add_sc()
#     created_t = []
#     buses = get_components(ACBus, system_ed)
#     buses_uc = get_components(ACBus, system)
#     for (b, b_uc) in zip(collect(buses), collect(buses_uc))
#         @assert get_name(b) == get_name(b_uc)
#         t = ThermalStandard("SC_$(get_name(b))", true, true, b, 0, 0, 100, (min=0, max=0), (min=-1000, max=1000), nothing, ThermalGenerationCost(variable = zero(CostCurve), fixed = 0.0, start_up = 0.0, shut_down = 0.0,), 100, nothing, false, PrimeMovers.CT)
#         # try
#         if get_bustype(b) != ACBusTypes.REF
#             set_bustype!(b, ACBusTypes.PV)
#             set_bustype!(b_uc, ACBusTypes.PV)
#         end
#         add_component!(system_ed, t)
#         add_component!(system, t)

#         push!(created_t, t)
#         # catch e
#             # @show e
#             # continue
#         # end
#     end

#     dates = range(DateTime("2019-01-01T00:00:00"), step = Dates.Hour(1), length = 8760)

#     time_series_p = SingleTimeSeries("max_active_power", TimeArray(dates, zeros(8760)), scaling_factor_multiplier = get_max_active_power)
#     add_time_series!(system_ed, created_t, time_series_p)
#     add_time_series!(system, created_t, time_series_p)

#     transform_single_time_series!(
#         system_ed,
#         Dates.Hour(1),  # horizon: 1 hr ahead
#         Dates.Hour(1),  # interval 
#     );

#     transform_single_time_series!(
#         system,
#         Dates.Hour(1),  # horizon: 1 hr ahead
#         Dates.Hour(1),  # interval 
#     );
# end



# ggg = get_components(Generator, system)
# i = 0
# for g in ggg
#     b = get_bus(g)
#     if get_bustype(b) == ACBusTypes.PQ
#         i += 1
#         @show i, typeof(g), get_name(g), get_name(b)
#     end
# end
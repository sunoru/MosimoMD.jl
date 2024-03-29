function md_init(;
    timestep::Real,
    temperature::Real,
    compressed_temperature::Real,
    temp_control_period::Integer,
    initial_steps::Integer,
    cooling_steps::Integer,
    temp_control_steps::Integer,
    relax_steps::Integer,
    relax_iterations::Integer,
    data_steps::Integer,
    taping_period::Integer=0,
    output_dir::AbstractString,
    seed::Nullable{Integer}=nothing,
    model::MosiModel=UnknownModel(),
    integrator_params::IntegratorParameters=VerletParameters()
)
    if model isa UnknownModel
        throw(SimulationError("model not defined"))
    end

    seed = make_seed(seed)

    setup = MDSetup(;
        timestep,
        temperature,
        compressed_temperature, temp_control_period,
        initial_steps, cooling_steps,
        temp_control_steps, relax_steps, relax_iterations,
        data_steps,
        taping_period,
        output_dir,
        seed,
        model,
        integrator_params
    )

    init_output(setup)

    setup
end

# Use verlet as default integrator.
function get_integrator(setup::MDSetup, system::MosiSystem)
    rs = positions(system)
    forces = similar(rs)
    VerletIntegrator(
        rs, velocities(system),
        setup.timestep,
        i -> mass(setup.model, i),
        rs -> force_function(setup.model, rs; inplace=forces)
    )
end

function MosimoBase.init_state(setup::MDSetup; force=false)
    rng = new_rng(setup.seed)
    system = MosimoBase.generate_initial(setup.model, MolecularSystem; rng)
    rescale_temperature!(system, setup.model, setup.temperature)
    integrator = get_integrator(setup, system)
    tape_files = prepare_tape(setup; force)
    state = MDState(;
        rng,
        integrator,
        system,
        setup,
        tape_files
    )
end

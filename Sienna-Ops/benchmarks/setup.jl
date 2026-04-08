# Setup script to create a Project/Manifest with exact package versions
# The script activates the directory where it lives, so running it from any
# working directory will create `Project.toml`/`Manifest.toml` next to this
# script. Example usage:
#  cd <dir-containing-setup.jl> && julia setup.jl
#  julia path/to/setup.jl

using Pkg

# Activate the script's directory as the project (creates Project.toml if missing)
# using @__DIR__ ensures the toml files are created next to this script.
Pkg.activate(@__DIR__)

# Add exact versions of required packages
# Pkg.add(Pkg.PackageSpec(name="CSV", version="0.10.16"))
# Pkg.add(Pkg.PackageSpec(name="DataFrames", version="1.8.1"))
Pkg.add(Pkg.PackageSpec(name="HiGHS", version="1.22.2"))
Pkg.add(Pkg.PackageSpec(name="HydroPowerSimulations", version="0.13.1"))
Pkg.add(Pkg.PackageSpec(name="Ipopt", version="1.14.1"))
Pkg.add(Pkg.PackageSpec(name="PowerAnalytics", version="1.1.0"))
Pkg.add(Pkg.PackageSpec(name="PowerGraphics", version="0.21.0"))
Pkg.add(Pkg.PackageSpec(name="PowerSimulations", version="0.32.4"))
Pkg.add(Pkg.PackageSpec(name="PowerSystemCaseBuilder", version="2.2.1"))
Pkg.add(Pkg.PackageSpec(name="PowerSystems", version="5.7"))

# Ensure Manifest.toml is generated and all deps are downloaded/built
Pkg.instantiate()

# Show the resulting environment for verification
Pkg.status()


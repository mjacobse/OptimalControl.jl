using ControlToolbox
using Plots
using Test

for name in (
    "utils",
    "steepest",
)
    @testset "$name" begin
        include("test_$name.jl")
    end
end
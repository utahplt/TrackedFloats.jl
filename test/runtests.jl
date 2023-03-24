using Test

@testset "smoke tests" begin
  @test true
end

include("injector_tests.jl")

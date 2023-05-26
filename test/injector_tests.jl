using Test

println("Loading FloatTracker…")
include("../src/FloatTracker.jl")
using .FloatTracker

ft_init()

println("FloatTracker loaded")

@testset "should_inject basic behavior" begin
  i1 = InjectorConfig(odds=1, n_inject=2)
  @test should_inject(i1)

  i2 = InjectorConfig(odds=1, n_inject=0)
  @test ! should_inject(i2)

  i3 = InjectorConfig(odds=10^30, n_inject=2) # No way that this should return true twice in that range
  @test !(should_inject(i3) && should_inject(i3))
end

@testset "should_inject recording basics" begin
  tmp_file = tempname()         # This should automatically get cleaned up
  i1 = InjectorConfig(odds=10, n_inject=10, record=tmp_file)
  l1 = zeros(Bool, 100)
  l2 = zeros(Bool, 100)
  for i in 1:100
    l1[i] = should_inject(i1)
  end

  # Ok, now check the replay
  i2 = InjectorConfig(replay=tmp_file)
  for i in 1:100
    l2[i] = should_inject(i2)
  end
  for i in 1:100
    @test l1[i] === l2[i]
  end
end

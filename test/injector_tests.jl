using Test

include("../src/Injector.jl")

@testset "should_inject basic behavior" begin
  i1 = Injector(true, 1, 2, [])
  @test should_inject(i1)

  i2 = Injector(true, 1, 0, [])
  @test ! should_inject(i2)

  i3 = Injector(true, 10^30, 2, []) # No way that this should return true twice in that range
  @test !(should_inject(i3) && should_inject(i2))
end

using Test

include("../src/Injector.jl")

@testset "should_inject basic behavior" begin
  println("t1")
  i1 = make_injector(odds=1, n_inject=2)
  println(i1)
  @test should_inject(i1)

  println("t2")
  i2 = make_injector(odds=1, n_inject=0)
  @test ! should_inject(i2)

  println("t3")
  i3 = make_injector(odds=10^30, n_inject=2) # No way that this should return true twice in that range
  @test !(should_inject(i3) && should_inject(i3))
end

# @testset "should_inject recording basics" begin
#   tmp_file = tempname()         # This should automatically get cleaned up
#   i1 = make_injector(odds=10, n_inject=10, record=tmp_file)
#   l1 = zeros(Bool, 100)
#   l2 = zeros(Bool, 100)
#   for i in 1:100
#     l1[i] = should_inject(i1)
#   end

#   # Ok, now check the replay
#   i2 = make_injector(replay=tmp_file)
#   for i in 1:100
#     l2[i] = should_inject(i2)
#     # @test should_inject(i2) == l1[i]
#   end
#   for i in 1:100
#     println("$(l1[i])	$(l2[i])")
#   end
# end

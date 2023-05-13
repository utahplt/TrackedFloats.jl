using Test

@testset "recording captures detailed information" begin
end

@testset "recording session basics" begin
  # Make sure that correct number of runs happen
end

@testset "recording session coverage" begin
  # Ensure test will move on over previously recorded points
end

@testset "injection point equivalence" begin
  # Ensure that module equivalence works; i.e. if we say that stack frames are
  # equivalent modulo a particular file+line combo in a module, then we should
  # treat different calls to that point as being the same.
end

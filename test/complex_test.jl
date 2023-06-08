using Test
using FloatTracker

@testset "Constructing tracked complex numbers" begin
  scotty_tt = 0.0 + 1.0im           # Our imaginary friend

  @test TrackedFloat64(scotty_tt) == ComplexF64(TrackedFloat64(0.0), TrackedFloat64(1.0))
end

@testset "Arithmetic works with tracked values" begin
  scotty_tt  = 0.0 + 1.0im
  sir_zabble = 0.0 + 2.0im

  # Do we have a homomorphism?
  @test TrackedFloat64(scotty_tt + sir_zabble) == TrackedFloat64(scotty_tt) + TrackedFloat64(sir_zabble)
end

@testset "events get recorded" begin
  ft_init()
  config_session(testing=true)
  tmp1 = tempname()         # This should automatically get cleaned up
  exclude_stacktrace([:kill,:inject])
  config_logger(filename=tmp1, buffersize=1, maxFrames=3)

  scotty_tt = TrackedFloat64(0.0 + 1.0im) / 0

  @test countlines(tmp1) == 10  # 5 for the NaN, 5 for the Inf
end

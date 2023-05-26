using Test

include("../src/FloatTracker.jl")
using .FloatTracker

@testset "set_*_config! tests don't override" begin
  global_config = ft__get_global_ft_config_for_test()
  mirror = FtConfig(LoggerConfig(),
                           InjectorConfig(),
                           SessionConfig())
  mirror.log.filename = global_config.log.filename
  @test "$global_config" == "$mirror"

  set_injector_config!(active=true, odds=42)
  @test "$global_config" != "$mirror"
  mirror.inj.active = true
  mirror.inj.odds = 42
  @test "$global_config" == "$mirror"

  set_injector_config!(active=false)
  @test "$global_config" != "$mirror"
  mirror.inj.active = false
  @test "$global_config" == "$mirror"
  @test global_config.inj.odds == 42
end

@testset "timestamp gets added correctly to log config" begin
  global_config = ft__get_global_ft_config_for_test()
  fln = global_config.log.filename

  @test match(r"\d+-ft_log", fln) !== nothing

  set_logger_config!(filename="foobar")
  println(global_config.log.filename)
  @test match(r"\d+-foobar", global_config.log.filename) !== nothing
end


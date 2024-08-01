using Test

using TrackedFloats

@testset "config_* doesn't override everything" begin
  global_config = ft__get_global_ft_config_for_test()
  mirror = FtConfig(LoggerConfig(),
                    InjectorConfig(),
                    SessionConfig())
  mirror.log.filename = global_config.log.filename
  mirror.ses.sessionId = global_config.ses.sessionId
  @test "$global_config" == "$mirror"

  config_injector(active=true, odds=42)
  @test "$global_config" != "$mirror"
  mirror.inj.active = true
  mirror.inj.odds = 42
  @test "$global_config" == "$mirror"

  config_injector(active=false)
  @test "$global_config" != "$mirror"
  mirror.inj.active = false
  @test "$global_config" == "$mirror"
  @test global_config.inj.odds == 42
end

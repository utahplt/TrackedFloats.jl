using Test

using FloatTracker

println("FloatTracker loaded")

f5(n) = n-2

f4(n) = f5(n+n)

f3(n) = f4(n-1)

f2(n) = f3(n*2)

f1(n) = f2(n+1)

f0(n) = f1((n * n - 4.0) / (n - 2.0))

@testset "maxFrames: only print out n stack frames" begin
  ft_init()
  config_session(testing=true)
  tmp1 = tempname()         # This should automatically get cleaned up
  tmp2 = tempname()

  floaty = TrackedFloat32(2.0)

  exclude_stacktrace([:kill,:inject])

  config_logger(filename=tmp1, buffersize=1)
  f0(floaty)
  ft_flush_logs()

  # We get 6 log events, and with this config there should be 6 lines + space
  # for every event
  @test countlines(tmp1) > 7 * 6

  config_logger(filename=tmp2, maxFrames=3)
  f0(floaty)
  ft_flush_logs()

  # We get the ((check_error line) + (3 lines of context) + (blank line) = 5) * (6 events)
  @test countlines(tmp2) == 5 * 6
end

@testset "maxLogs: only log n events then stop" begin
  ft_init()
  config_session(testing=true)
  tmp1 = tempname()         # This should automatically get cleaned up
  tmp2 = tempname()

  floaty = TrackedFloat32(2.0)

  exclude_stacktrace([:kill,:inject])

  config_logger(filename=tmp1, maxFrames=1, buffersize=1)
  f0(floaty)
  ft_flush_logs()

  # We get the ((check_error line) + (1 lines of context) + (blank line) = 3) * (6 events)
  @test countlines(tmp1) == 18

  config_logger(filename=tmp2, maxLogs=3)
  f0(floaty)
  ft_flush_logs()

  # We get the ((check_error line) + (1 lines of context) + (blank line) = 3) * (3 events)
  @test countlines(tmp2) == 9
end

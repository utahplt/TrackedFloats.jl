using Test

println("Loading FloatTracker…")
include("../src/FloatTracker.jl")
using .FloatTracker

println("FloatTracker loaded")

f5(n) = n-2

f4(n) = f5(n+n)

f3(n) = f4(n-1)

f2(n) = f3(n*2)

f1(n) = f2(n+1)

f0(n) = f1((n * n - 4.0) / (n - 2.0))

@testset "maxFrames: only print out n stack frames" begin
  tmp_file = tempname()         # This should automatically get cleaned up
  # WORKING HERE: trying to make it so I can configure the logs to go out to the temp file
  config_session!(testing=true)
  config_logger!(filename=tmp_file, maxFrames=3, printToStdOut=true)

  floaty = TrackedFloat32(2.0)
  f0(floaty)
  write_out_logs()
  println("file: $tmp_file")
  run(`cat $tmp_file`)
end

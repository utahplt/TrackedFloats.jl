# Run this by entering the Julia REPL and running
   # include("test/logger_perf_tests.jl")

using TrackedFloats: TrackedFloat64, tf_flush_logs, tf_exclude_stacktrace, set_logger
using FileIO, Profile, FlameGraphs, Plots, ProfileView

function track(loops)
  acc = []

  for i in 1:loops
    foo = TrackedFloat64(10.0)
    bar = TrackedFloat64(5.0)
    baz = bar - (i % 6)
    push!(acc, (foo - (i % 18)) * (bar / baz) + (bar / baz))
  end

  return acc
end

function no_track(loops)
  acc = []

  for i in 1:loops
    foo = 10.0
    bar = 5.0
    baz = bar - (i % 6)
    push!(acc, (foo - (i % 18)) * (bar / baz) + (bar / baz))
  end

  return acc
end

loops = 50_000

set_logger(filename="log_perf", buffersize=10_000)
tf_exclude_stacktrace([:prop,:kill])

no_track(1)
track(1)

println("No tracking:")
Profile.clear();
@profview no_track(loops)
# notrack_g = flamegraph(C=true)

println("Halting for input")
readline()

# FlameGraphs.save("notrack_perf.jlprof", Profile.retrieve()...)
# Profile.clear();

println("Tracking:")
@profview track(loops)
# track_g = flamegraph(C=true)
# FlameGraphs.save("track_perf.jlprof", Profile.retrieve()...)

println("Halting for input")
readline()

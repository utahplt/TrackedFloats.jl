module FloatTracker

export TrackedFloat16, TrackedFloat32, TrackedFloat64, FunctionRef, print_log, write_out_logs, set_inject_nan, set_exclude_stacktrace, set_logger
import Base

include("Event.jl")
include("Logger.jl")
include("Injector.jl")
include("TrackedFloat.jl")

end # module

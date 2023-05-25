module FloatTracker

export TrackedFloat16, TrackedFloat32, TrackedFloat64, FunctionRef
export LoggerConfig, set_logger_config!, set_exclude_stacktrace!, print_log, write_out_logs
export InjectorConfig, set_injector_config!, enable_nan_injection!, enable_injection_recording!
export SessionConfig

include("SharedStructs.jl")
include("Config.jl")
include("Event.jl")
include("Logger.jl")
include("Injector.jl")
include("TrackedFloat.jl")

end

module FloatTracker

export FtConfig, ft_init, TrackedFloat16, TrackedFloat32, TrackedFloat64, FunctionRef
export LoggerConfig, config_logger, set_exclude_stacktrace, print_log, write_out_logs
export InjectorConfig, config_injector, enable_nan_injection, disable_nan_injection!, enable_injection_recording!, set_injection_replay!
export SessionConfig

include("SharedStructs.jl")     # Structures used in multiple places throughout FloatTracker
include("Config.jl")            # Primary interface routines: routines to control injection, logging, etc.
include("Event.jl")             # Routines for diagnosing exceptional events
include("Logger.jl")            # Formatting and writing of error/event logs
include("Injector.jl")          # NaN-injection logic
include("TrackedFloat.jl")      # Principle datatype; overrides of all Base.* functions

__init__() = ft_init()

end

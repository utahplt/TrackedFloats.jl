module TrackedFloats

export FtConfig, tf_init, TrackedFloat16, TrackedFloat32, TrackedFloat64, FunctionRef
export LoggerConfig, tf_config_logger, tf_exclude_stacktrace, tf_print_log, tf_flush_logs
export InjectorConfig, tf_config_injector, tf_enable_nan_injection, tf_disable_nan_injection, tf_enable_inf_injection, tf_disable_inf_injection, tf_record_injection, tf_replay_injection
# migration: start again with adding tf_ to enable_nan_injection
export SessionConfig, tf_config_session

include("SharedStructs.jl")     # Structures used in multiple places throughout TrackedFloats
include("Config.jl")            # Primary interface routines: routines to control injection, logging, etc.
include("Event.jl")             # Routines for diagnosing exceptional events
include("Logger.jl")            # Formatting and writing of error/event logs
include("Injector.jl")          # NaN-injection logic
include("TrackedFloat.jl")      # Principle datatype; overrides of all Base.* functions

# Call tf_init() when module gets loaded up
__init__() = tf_init()

end

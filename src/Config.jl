#
# Unified config for FloatTracker
# ===============================
#
# Contents:
#
#  - Error logging config
#  - Injector config
#  - Session config
#  - Global config instance

using Dates

# Singleton to represent unrestricted max{Logs,Gens,Props,Kills,Events}
struct Unbounded
end

#
# Error logging config
#

"""
Struct containing all configuration for the logger.

## Fields

 - `filename::String` Basename of the file to write logs to.

   Constructors automatically prefix the timestamp to the beginning of this
   basename so the logs are grouped together chronologically.

 - `buffersize::Int` Number of logs to buffer in memory before writing to file.

   Defaults to 1000. Decrease if you are crashing without getting the logs that you need.

 - `printToStdOut::Bool` Whether or not to write logs to STDOUT; defaults  to `false`.

 - `cstg::Bool` Write logs in CSTG format.

 - `cstgLineNum::Bool` Include the line number in CSTG output.

 - `cstgArgs::Bool` Include arguments to functions in CSTG output.

 - `maxLogs::Union{Int,Unbounded}` Maximum number of events to log; defaults to `Unbounded`.

 - `exclusions::Array{Symbol}` Events to not log; defaults to `[:prop]`.
"""
mutable struct LoggerConfig
  filename::String
  buffersize::Int
  printToStdOut::Bool
  cstg::Bool
  cstgLineNum::Bool
  cstgArgs::Bool
  maxLogs::Union{Int,Unbounded}
  exclusions::Array{Symbol}
end
LoggerConfig(filename) =
  LoggerConfig(filename, 1000)
LoggerConfig(filename, buff_size) =
  LoggerConfig(filename=filename, buffersize=buff_size, print=false, cstg=false, cstgLineNum=true, cstgArgs=true)
LoggerConfig(filename, buff_size, cstg) =
  LoggerConfig(filename=filename, buffersize=buff_size, print=false, cstg=cstg, cstgLineNum=true, cstgArgs=true)

function LoggerConfig(; filename="ft_log", buffersize=1000, print=false, cstg=false, cstgLineNum=true, cstgArgs=true,
                      max_logs=Unbounded(), exclusions=[:prop])
  LoggerConfig(filename, buffersize, print, cstg, cstgLineNum, cstgArgs, max_logs, exclusions)
end

#
# Injector config
#

struct InjectorScript
  script::Array{ReplayPoint}
end
InjectorScript() = InjectorScript([])
InjectorScript(script_name::String) = InjectorScript(parse_replay_file(script_name))

function parse_replay_file(replay::String)::Array{ReplayPoint}
  return [parse_replay_line(l) for l in readlines(replay)]
end

function parse_replay_line(line::String)::ReplayPoint
  m = match(r"^(\d+), ([^,]*), (.*)$", line)
  return ReplayPoint(parse(Int64, m.captures[1]), Symbol(m.captures[2]), split(m.captures[3]))
end

"""
Struct describing parameters for injecting NaNs

## Fields

 - `active::Boolean` inject only if true

 - `n_inject::Int` maximum number of NaNs to inject; gets decremented every time
   a NaN gets injected

 - `odds::Int` inject a NaN with 1:odds probability—higher value → rarer to
   inject

 - `functions::Array{FunctionRef}` if given, only inject NaNs when within these
   functions; default is to not discriminate on functions

 - `libraries::Array{String}` if given, only inject NaNs when within this library.

 - `record::String` if given, record injection invents in a way that can be
   replayed later with the `replay` argument.

 - `replay::String` if given, ignore all previous directives and use this file
   for injection replay.

`functions` and `libraries` work together as a union: i.e. the set of possible NaN
injection points is a union of the places matched by `functions` and `libraries`.

"""
mutable struct InjectorConfig
  active::Bool
  odds::Int64
  n_inject::Int64
  functions::Array{FunctionRef}
  libraries::Array{String}
  replay::String
  record::String

  # private fields
  place_counter::Int64
  replay_script::InjectorScript
  replay_head::Int64
end

InjectorConfig(odds::Int64, n_inject::Int64) = InjectorConfig(odds=odds, n_inject=n_inject)

function InjectorConfig(; should_inject::Bool=true, odds::Int64=10, n_inject::Int64=1, functions=[], libraries=[], replay="", record="")
  script =
    if replay !== ""
      parse_replay_file(replay)
    else
      []
    end
  return InjectorConfig(should_inject, odds, n_inject, functions, libraries, replay, record, 0, InjectorScript(script), 1)
end

#
# Recording session configuration
#

mutable struct SessionConfig
  maxGens::Union{Int,Unbounded}
  maxProps::Union{Int,Unbounded}
  maxKills::Union{Int,Unbounded}
  maxEvents::Union{Int,Unbounded}
  sessionId::String                # Defaults to current timestamp like yyyymmmddHHMMss
end
function SessionConfig()
  now_str = Dates.format(now(), "yyyymmddHHMMSS")
  SessionConfig(Unbounded(), Unbounded(), Unbounded(), Unbounded(), now_str)
end

"""
FloatTracker config struct

## Logger Config
## Injector Config
## Session Config
"""
mutable struct FtConfig
  log::LoggerConfig
  inj::InjectorConfig
  ses::SessionConfig
end

#
# Global config instance
#

# Don't forget to call `ft_init()`!!!
ft_config = nothing

"""
    ft_init()

Initialize the global FloatTracker configuration. (Automatically called when using function by `__init__`)

We need to make this a function, otherwise it can cache the value of the
timestamp used for writing unique log files.
"""
function ft_init()
  global ft_config = FtConfig(LoggerConfig(), InjectorConfig(), SessionConfig())
end

# Internal function
function patch_config!(the_struct; kwargs ...)
  for (k, v) in kwargs
    setfield!(the_struct, k, v)
  end
end

# Exported only for testing
ft__get_global_ft_config_for_test() = ft_config
export ft__get_global_ft_config_for_test

"""
    config_logger!(log::LoggerConfig)
    config_logger!(; args...)

Set the logger for the global FloatTracker configuration instance.

Takes either a `LoggerConfig` struct, or the same keyword arguments as the
`LoggerConfig` constructor.

In the case where only a few arguments are specified, it will override only
those fields, i.e. the entire LoggerConfig won't be replaced. This is useful,
for example, if you need to adjust a field in the middle of a test.
"""
config_logger!(log::LoggerConfig) = ft_config.log = log
config_logger!(; args...) = patch_config!(ft_config.log; args...)

"""
    config_injector!(log::InjectorConfig)
    config_injector!(; args...)

Set the injector for the global FloatTracker configuration instance.

Takes either a `InjectorConfig` struct, or the same keyword arguments as the
`InjectorConfig` constructor.

Passing a partial list of keyword arguments has the same behavior as it does
with `config_logger!`.
"""
config_injector!(inj::InjectorConfig) = ft_config.inj = inj
config_injector!(; args...) = patch_config!(ft_config.inj; args...)

"""
    config_session!(log::SessionConfig)
    config_session!(; args...)

Set the session for the global FloatTracker configuration instance.

Takes either a `SessionConfig` struct, or the same keyword arguments as the
`SessionConfig` constructor.

Passing a partial list of keyword arguments has the same behavior as it does
with `config_logger!`.
"""
config_session!(ses::SessionConfig) = ft_config.ses = ses
config_session!(; args...) = patch_config!(ft_config.ses; args...)

"""
    set_exclude_stacktrace!(exclusions = [:prop])

Globally set the types of stack traces to not collect.

See documentation for the `event()` function for details on the types of events
that can be put into this list.

Convenience function; You can also set the stack trace exclusions with
a keyword argument to `config_logger!`.
"""
set_exclude_stacktrace!(exclusions = [:prop]) = ft_config.log.exclusions = exclusions

"""
    enable_nan_injection!(n_inject::Int)

Turn on NaN injection and injection `n_inject` NaNs. Does not modify odds,
function and library lists, or recording/replay state.

    enable_nan_injection!(; odds::Int = 10, n_inject::Int = 1, functions::Array{FunctionRef} = [], libraries::Array{String} = [])

Turn on NaN injection. Optionally configure the odds for injection, as well as
the number of NaNs to inject, and the functions/libraries in which to inject
NaNs. Overrides unspecified arguments to their defaults.
"""
function enable_nan_injection!(n_inject::Int)
  ft_config.inj.active    = true
  ft_config.inj.n_inject   = n_inject
end

function enable_nan_injection!(; odds::Int = 10, n_inject::Int = 1, functions::Array{FunctionRef} = [], libraries::Array{String} = [])
  ft_config.inj.active    = true
  ft_config.inj.odds      = odds
  ft_config.inj.n_inject   = n_inject
  ft_config.inj.functions = functions
  ft_config.inj.libraries = libraries
end

"""
    disable_nan_injection!()

Turn off NaN injection.

If you want to re-enable NaN injection after calling `disable_nan_injection!`,
consider using the one-argument form of `enable_nan_injection!(n_inject::Int)`.
"""
disable_nan_injection!() = ft_config.inj.active = false

"""
    enable_injection_recording!(recording_file::String="ft_recording")

Turn on recording.
"""
enable_injection_recording!(recording_file::String="ft_recording") = ft_config.inj.record = recording_file

"""
    set_injection_replay!(replay_file::String)

Sets the injector to read from a replay file.

Note that this overwrites all previous configuration to the injector file, as
once you are replaying an injection recording, all other configuration ceases to
matter.
"""
set_injection_replay!(replay_file::String) = ft_config.inj = InjectorConfig(replay=replay_file)

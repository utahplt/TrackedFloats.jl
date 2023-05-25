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

 - `outputCSTG::Bool` Write logs in CSTG format.

 - `cstgLineNum::Bool` Include the line number in CSTG output.

 - `cstgArgs::Bool` Include arguments to functions in CSTG output.

 - `maxLogs::Union{Int,Unbounded}` Maximum number of events to log; defaults to `Unbounded`.

 - `exclusions::Array{Symbol}` Events to not log; defaults to `[:prop]`.
"""
mutable struct LoggerConfig
  filename::String
  buffersize::Int
  printToStdOut::Bool
  outputCSTG::Bool
  cstgLineNum::Bool
  cstgArgs::Bool
  maxLogs::Union{Int,Unbounded}
  exclusions::Array{Symbol}
end
LoggerConfig() =
  LoggerConfig("ft_log", 1000)
LoggerConfig(filename) =
  LoggerConfig(filename, 1000)
LoggerConfig(filename, buff_size) =
  LoggerConfig(filename=filename, buffersize=buff_size, print=false, cstg=false, cstgLineNum=true, cstgArgs=true)
LoggerConfig(filename, buff_size, cstg) =
  LoggerConfig(filename=filename, buffersize=buff_size, print=false, cstg=cstg, cstgLineNum=true, cstgArgs=true)

function LoggerConfig(; filename="default", buffersize=1000, print=false, cstg=false, cstgLineNum=true, cstgArgs=true,
                      max_logs=Unbounded, exclusions=[:prop])
  now_str = Dates.format(now(), "yyyymmddHHMMss")
  LoggerConfig("$now_str-$filename", buffersize, print, cstg, cstgLineNum, cstgArgs, max_logs, exclusions)
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

 - `ninject::Int` maximum number of NaNs to inject; gets decremented every time
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
  ninject::Int64
  functions::Array{FunctionRef}
  libraries::Array{String}
  replay::String
  record::String
  session::String

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
  return InjectorConfig(should_inject, odds, n_inject, functions, libraries, replay, record, "", 0, script, 1)
end

#
# Recording session configuration
#

mutable struct SessionConfig
  maxGens::Union{Int,Unbounded}
  maxProps::Union{Int,Unbounded}
  maxKills::Union{Int,Unbounded}
  maxEvents::Union{Int,Unbounded}
end
SessionConfig() = SessionConfig(Unbounded, Unbounded, Unbounded, Unbounded)

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

ft_config = FtConfig(LoggerConfig(), InjectorConfig(), SessionConfig())

set_global_logger!(log::LoggerConfig)     = ft_config.log = log
set_global_injector!(inj::InjectorConfig) = ft_config.inj = inj
set_global_session!(ses::SessionConfig)   = ft_config.ses = ses

"""
    set_exclude_stacktrace!(exclusions = [:prop])

Globally set the types of stack traces to not collect.

See documentation for the `event()` function for details on the types of events
that can be put into this list.
"""
set_exclude_stacktrace!(exclusions = [:prop]) = ft_config.log.exclusions = exclusions

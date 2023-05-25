#
# Unified config for FloatTracker
#

# Singleton to represent unrestricted max{Logs,Gens,Props,Kills,Events}
struct Unbounded
end

# Error logging configuration
struct LoggerConfig
  filename::String
  buffersize::Int
  printToStdOut::Bool
  outputCSTG::Bool
  cstgLineNum::Bool
  cstgArgs::Bool
  maxLogs::Union{Int,Unbounded}
end

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
struct InjectorConfig
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

# Recording session configuration
struct SessionConfig
  maxGens::Union{Int,Unbounded}
  maxProps::Union{Int,Unbounded}
  maxKills::Union{Int,Unbounded}
  maxEvents::Union{Int,Unbounded}
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

# Global config instance

ft_config = FtConfig()

set_global_logger!(log::LoggerConfig)     = ft_config.log = log
set_global_injector!(inj::InjectorConfig) = ft_config.inj = inj
set_global_session!(ses::SessionConfig)   = ft_config.ses = ses

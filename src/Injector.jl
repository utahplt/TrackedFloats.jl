using Base.StackTraces
using Base.Iterators

struct FunctionRef
  name::Symbol
  file::Symbol
end

struct ReplayPoint
  counter::Int64
  check::Symbol
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
mutable struct Injector
  active::Bool
  odds::Int64
  ninject::Int64
  functions::Array{FunctionRef}
  libraries::Array{String}
  replay::String
  record::String

  # private fields
  place_counter::Int64
  replay_script::Array{ReplayPoint}
  replay_head::Int64
end

function make_injector(; should_inject::Bool=true, odds::Int64=10, n_inject::Int64=1, functions=[], libraries=[], replay="", record="")
  script =
    if replay !== ""
      parse_replay_file(replay)
    else
      []
    end
  return Injector(should_inject, odds, n_inject, functions, libraries, replay, record, 0, script, 1)
end

function parse_replay_file(replay::String)::Array{ReplayPoint}
  return [parse_replay_line(l) for l in readlines(replay)]
end

function parse_replay_line(line::String)::ReplayPoint
  m = match(r"^(\d+), (.*)$", line)
  return ReplayPoint(parse(Int64, m.captures[1]), Symbol(m.captures[2]))
end

"""
    should_inject(i::Injector)

Return whether or not we should inject a `NaN`.

Decision process:

 - Checks whether or not the given injector is active.

 - Checks that there are some NaNs remaining to inject.

 - Rolls an `Injector.odds`-sided die; if 1, proceed, otherwise, don't do
   anything.

 - Checks that we're inside the scope of a function in `Injector.functions` OR
   that we're in a library that we're interested in. If yes, inject.

 - Defaults to not injecting.
"""
function should_inject(i::Injector)::Bool
  i.place_counter += 1

  # Are we replaying a recording?
  if i.replay !== ""
    return handle_replay(i)
  end

  if i.active && i.ninject > 0 && rand(1:i.odds) == 1
    if i.record !== ""
      # We're recording this
      did_injectp = injectable_region(i, stacktrace())
      if did_injectp
        fh = open(i.record, "a")
        println(fh, "$(i.place_counter), $(frame_file(drop_ft_frames(stacktrace())[1]))")
        close(fh)
      end
      return did_injectp
    else
      return injectable_region(i, stacktrace())
    end
  end

  return false
end

function handle_replay(i::Injector)::Bool
  script = i.replay_script
  head = i.replay_head
  place = i.place_counter

  # End of recording?
  if length(script) < head
    return false
  end

  # Match?
  if place === script[head].counter && frame_file(drop_ft_frames(stacktrace())[1]) === script[head].check
    i.replay_head += 1
    return true
  end
  return false
end

@inline function decrement_injections(i::Injector)
  i.ninject = i.ninject - 1
end

@inline function drop_ft_frames(frames)
  collect(Iterators.dropwhile((frame -> frame_library(frame) == "FloatTracker"), frames))
end

"""
    injectable_region(i::Injector, frames::StackTrace)::Bool

Returns whether or not the current point in the code (indicated by the
StackTrace) is a valid point to inject a NaN.
"""
function injectable_region(i::Injector, raw_frames::StackTraces.StackTrace)::Bool
  # Drop FloatTracker frames
  frames = drop_ft_frames(raw_frames)

  # If neither functions nor libraries are specified, inject as long as we're
  # not inside the standard library.
  if isempty(i.functions) && isempty(i.libraries) && frame_library(frames[1]) !== nothing
    return true
  end

  # First check the functions set: the head of the stack trace should all be in
  # the file in question; somewhere in that set should be function specified.
  if !isempty(i.functions)
    interested_files = map((refs -> refs.file), i.functions)
    in_file_frame_head = Iterators.takewhile((frame -> frame_file(frame) in interested_files), frames)
    if any((frame -> FunctionRef(frame.func, frame_file(frame)) in i.functions), in_file_frame_head)
      return true
    end
  end

  # Next check the library set: if we're inside a library that we're interested
  # in, go ahead and inject
  if !isempty(i.libraries)
    if frame_library(frames[1]) in i.libraries
      return true
    end
  end

  # Default: don't inject
  return false
end

getmodule(_) = nothing
getmodule(x::Base.StackTraces.StackFrame) = getmodule(x.linfo)
getmodule(x::Core.MethodInstance) = getmodule(x.def)
getmodule(x::Core.Method) = "$(x.module)"
getmodule(x::Core.Module) = "$x"

function frame_file(frame)::Symbol
  return Symbol(split(String(frame.file), ['/', '\\'])[end])
end

"""
    frame_library(frame::StackTraces.StackFrame)::Symbol

Return the name of the library that the current stack frame references.

Returns `nothing` if unable to find library.
"""
function frame_library(frame::StackTraces.StackFrame) # ::Union{String,Nothing}
  return getmodule(frame)
end

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
  println(script)
  return Injector(should_inject, odds, n_inject, functions, libraries, replay, record, 0, script, 1)
end

function parse_replay_file(replay::String)::Array{ReplayPoint}
  # println("replay: $replay")
  # for l in readlines(replay)
  #   println("line: '$l'")
  #   println("parse: $(parse_replay_line(l))")
  # end
  # println("replay: done")
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
    println("Replaying: place: $(i.place_counter); head: $(i.replay_head) next: $(i.replay_script[i.replay_head])")
    if i.place_counter == i.replay_script[i.replay_head].counter
      now = frame_file(drop_ft_frames(stacktrace())[1])
      ck  = i.replay_script[i.replay_head].check
      println("   counter match; file: '$now' check: '$ck'")
      println("   run check: $(now === ck)")
    end
    # Look to see if our list of events is triggered
    go = i.place_counter === i.replay_script[i.replay_head].counter && frame_file(drop_ft_frames(stacktrace())[1]) === i.replay_script[i.replay_head].check

    println("go? $go")

    if go
      i.replay_head += 1
    end

    return go
  end

  if i.active && i.ninject > 0 && rand(1:i.odds) == 1
    println("hit odds")
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
      # println("defer to injectable_region")
      return injectable_region(i, stacktrace())
    end
  end

  println("nope way")
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

function frame_file(frame)::Symbol
  return Symbol(split(String(frame.file), ['/', '\\'])[end])
end

"""
    frame_library(frame::StackTraces.StackFrame)::Symbol

Return the name of the library that the current stack frame references.

Returns `nothing` if unable to find library.

This is a hacky routine. Note that if we're inside of a "scratch space" (i.e.
while testing) then this returns the name name of the scratch space.
"""
function frame_library(frame::StackTraces.StackFrame) # ::Union{String,Nothing}
  # FIXME: this doesn't work with packages that are checked out locally
  lib = match(r".julia[\\/](packages|dev|scratchspaces)[\\/]([a-zA-Z][a-zA-Z0-9_.-]*)[\\/]", String(frame.file))

  if lib === nothing
    return nothing
  else
    return lib.captures[2]
  end
end

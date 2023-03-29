using Base.StackTraces
using Base.Iterators

struct FunctionRef
  name::Symbol
  file::Symbol
end

"""
Struct describing parameters for injecting NaNs

## Fields

 - `active::Boolean` inject only if true

 - `ninject::Int` maximum number of NaNs to inject; gets decremented every time
   a NaN gets injected

 - `odds::Int` inject a NaN with 1:odds probability—higher value → rarer to
   inject

 - `functions:Array{FunctionRef}` if given, only inject NaNs when within these
   functions; default is to not discriminate on functions

 - `libraries:Array{String}` if given, only inject NaNs when within this library.

`functions` and `libraries` work together as a union: i.e. the set of possible NaN
injection points is a union of the places matched by `functions` and `libraries`.

"""
mutable struct Injector
  active::Bool
  odds::Int
  ninject::Int
  functions::Array{FunctionRef}
  libraries::Array{String}
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
  if i.active && i.ninject > 0 && rand(1:i.odds) == 1
    println("I am able to inject; checking region...")
    return injectable_region(i, stacktrace())
  end

  return false
end

function decrement_injections(i::Injector)
  i.ninject = i.ninject - 1
end

"""
    injectable_region(i::Injector, frames::StackTrace)::Bool

Returns whether or not the current point in the code (indicated by the
StackTrace) is a valid point to inject a NaN.
"""
function injectable_region(i::Injector, raw_frames::StackTraces.StackTrace)::Bool
  # Drop FloatTracker frames
  frames = collect(Iterators.dropwhile((frame -> frame_library(frame) != "FloatTracker"), raw_frames))

  # If neither functions nor libraries are specified, inject as long as we're
  # not inside the standard library.
  if isempty(i.functions) && isempty(i.libraries) && frame_library(frames[1]) !== nothing
    println("No stipulations; good to inject")
    return true
  end

  # First check the functions set: the head of the stack trace should all be in
  # the file in question; somewhere in that set should be function specified.
  if !isempty(i.functions)
    interested_files = map((refs -> refs.file), i.functions)
    in_file_frame_head = Iterators.takewhile((frame -> frame_file(frame) in interested_files), frames)
    if any((frame -> FunctionRef(frame.func, frame_file(frame)) in i.functions), in_file_frame_head)
      println("Function/file match!")
      return true
    end
  end

  # Next check the library set: if we're inside a library that we're interested
  # in, go ahead and inject
  if !isempty(i.libraries)
    if frame_library(frames[1]) in i.libraries
      println("Library matches!")
      return true
    end
  end

  # Default: don't inject
  println("Nothing matches; not injecting")
  return false
end

function frame_file(frame)::Symbol
  return Symbol(split(String(frame.file), ['/', '\\'])[end])
end

"""
    frame_library(frame::StackTraces.StackFrame)::Symbol

Return the name of the library that the current stack frame references.

Returns `nothing` if unable to find library.
"""
function frame_library(frame::StackTraces.StackFrame) # ::Union{String,Nothing}
  # FIXME: this doesn't work with packages that are checked out locally
  lib = match(r".julia[\\/](packages|dev)[\\/]([a-zA-Z][a-zA-Z0-9_.-]*)[\\/]", String(frame.file))

  if lib === nothing
    return nothing
  else
    return lib.captures[2]
  end
end

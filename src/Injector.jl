using Base.StackTraces
using Base.Iterators

mutable struct Injector
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
  replay_script::Array{ReplayPoint}
  replay_head::Int64
end
Injector(odds::Int64, n_inject::Int64) = make_injector(odds=odds, n_inject=n_inject)

function make_injector(; should_inject::Bool=true, odds::Int64=10, n_inject::Int64=1, functions=[], libraries=[], replay="", record="")
  script =
    if replay !== ""
      parse_replay_file(replay)
    else
      []
    end
  return Injector(should_inject, odds, n_inject, functions, libraries, replay, record, "", 0, script, 1)
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
    st = stacktrace()
    if i.record !== ""
      # We're recording this
      did_injectp = injectable_region(i, st)
      if did_injectp
        write_replay_point(i, make_replay_point(i, st))
      end
      return did_injectp
    else
      return injectable_region(i, st)
    end
  end

  return false
end

function make_replay_point(i::Injector, st::StackTraces.StackTrace)::ReplayPoint
  this_file = frame_file(drop_ft_frames(st)[1])
  short_frames = map((f -> "$(frame_library(f)):$(frame_file(f)):$(frame_line(f))"), drop_ft_frames(st))
  ReplayPoint(i.place_counter, Symbol(this_file), short_frames)
end

function write_replay_point(i::Injector, rp::ReplayPoint)
  fh = open(i.record, "a")
  short_frames = join(rp.stack, " ")
  println(fh, "$(rp.counter), $(rp.check), $short_frames")
  close(fh)
end

function handle_replay(i::Injector)::Bool
  script = i.replay_script
  head = i.replay_head
  place = i.place_counter

  # End of recording?
  if length(script) < head
    return false
  end

  ff = frame_file(drop_ft_frames(stacktrace())[1])

  # Match?
  if place === script[head].counter && ff === script[head].check
    i.replay_head += 1
    println("Injecting NaN from replay point $place; file $(script[head].check)")
    return true
  elseif place === script[head].counter && ff !== script[head].check
    @error "At replay point $place but current file $ff ≠ $(script[head].check)"
  elseif place > script[head].counter
    @error "Replay point skipped"
  end

  return false
end

@inline function decrement_injections(i::Injector)
  i.ninject = i.ninject - 1
end

@inline function drop_ft_frames(frames)
  collect(Iterators.dropwhile((frame -> frame_library(frame) === "FloatTracker"), frames))
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
    if any((frame -> FunctionRef(frame.func, frame_file(frame), true) in i.functions), in_file_frame_head)
      return false
    end
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

frame_file(frame::StackTraces.StackFrame) = Symbol(split(String(frame.file), ['/', '\\'])[end])

frame_line(frame::StackTraces.StackFrame) = frame.line

"""
    frame_library(frame::StackTraces.StackFrame)::Symbol

Return the name of the library that the current stack frame references.

Returns `nothing` if unable to find library.
"""
function frame_library(frame::StackTraces.StackFrame) # ::Union{String,Nothing}
  # first try from a data structure; if that doesn't work use the hacky string-based method that can work for inlined functions.
  name = getmodule(frame)
  if isnothing(name)
    # FIXME: this doesn't work with packages that are checked out locally
    lib = match(r".julia[\\/](packages|dev|scratchspaces)[\\/]([a-zA-Z][a-zA-Z0-9_.-]*)[\\/]", String(frame.file))

    if isnothing(lib)
      return nothing
    else
      return "$(lib.captures[2])"
    end
  end
  return "$name"
end

function pp_frames(frames::StackTraces.StackTrace)
  for f::StackTraces.StackFrame in frames
    println("$(f.func) at $(f.file):$(f.line)")
  end
end

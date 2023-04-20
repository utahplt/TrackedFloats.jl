@inline function isfloaterror(x)
  x isa AbstractFloat && isnan(x)
end

"""
    Event

Struct representing some event in the life of a NaN.

`evt_type` options:

 - `:injected`
 - `:gen`
 - `:prop`
 - `:kill`
"""
struct Event
  evt_type::Symbol
  op::String
  args::Array{Any}
  result::Any
  trace::StackTraces.StackTrace
end

exclude_stacktrace = [:prop]

"""
    set_exclude_stacktrace(exclusions = [:prop])

Set the types of stack traces to not collect.

See documentation for the `event()` function for details on the types of events
that can be put into this list.
"""
function set_exclude_stacktrace(exclusions = [:prop])
  global exclude_stacktrace = exclusions
end

"""
    event(op, args, result, is_injected = false)

Construct an `Event` struct.

Uses the argument values and the return result to determine what kind of an
event we're looking at here. Types:

 - `:injected` --- injections
 - `:gen`      --- generating operations
 - `:prop`     --- NaN propagation
 - `:kill`     --- killing operations
"""
function event(op, args, result, is_injected = false) :: Event
  evt_type =
    if is_injected
      :injected
    elseif all(arg -> !isfloaterror(arg), args) && isfloaterror(result)
      :gen
    elseif any(arg -> isfloaterror(arg), args) && isfloaterror(result)
      :prop
    elseif any(arg -> isfloaterror(arg), args) && !isfloaterror(result)
      :kill
    end

  st = if evt_type in exclude_stacktrace
    Base.StackFrame[]
  else
    stacktrace()[2:end]
  end

  Event(evt_type, op, args, result, st)
end

function to_string(evt::Event)
  sts = join(["\t$st" for st in evt.trace], "\n")
  return "$(uppercase(string(evt.evt_type))) $(join(evt.args, ",")) -> $(evt.op) -> $(evt.result)\n $sts"
end

@inline function isfloaterror(x)
  x isa AbstractFloat && isnan(x)
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

  st = if evt_type in ft_config.log.exclusions
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

@inline function isfloaterror(x)
  x isa AbstractFloat && (isnan(x) || isinf(x))
end

@inline function float_error_kind(x)
  if isnan(x)
    :nan
  elseif isinf(x)
    :inf
  else
    :unknown
  end
end

"""
    event(op, args, result, is_injected = false)

Constructs one or more `Event` structs based off of the operation.

Uses the argument values and the return result to determine what kind of an
event we're looking at here. Types:

 - `:injected` --- injections
 - `:gen`      --- generating operations
 - `:prop`     --- NaN propagation
 - `:kill`     --- killing operations

Returns one or more events in a list
"""
function event(op, args, result, is_injected = false) :: Vector{Event}
  events = []

  for (predicate, type) in [((x -> x isa AbstractFloat && isnan(x)), :nan), ((x -> x isa AbstractFloat && isinf(x)), :inf)]
    evt_type =
      if is_injected
        :injected
      elseif all(arg -> !predicate(arg), args) && predicate(result)
        :gen
      elseif any(arg -> predicate(arg), args) && predicate(result)
        :prop
      elseif any(arg -> predicate(arg), args) && !predicate(result)
        :kill
      else
        continue                # no events generated for this category (nan vs inf)
      end

    st = if evt_type in tf_config.log.exclusions
      Base.StackFrame[]
    else
      stacktrace()[2:end]
    end

    push!(events, Event(type, evt_type, op, args, result, st))
  end

  events
end

function to_string(evt::Event)
  sts = join(["\t$st" for st in evt.trace], "\n")
  return "$(uppercase(string(evt.evt_type))) $(join(evt.args, ",")) -> $(evt.op) -> $(evt.result)\n $sts"
end

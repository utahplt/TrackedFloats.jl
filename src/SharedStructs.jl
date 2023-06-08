"""
Struct to describe a function location; used by the Injector

The `avoid` field defaults to `false`—setting this to `true` will make it so
that if that function will *not* be considered a candidate for injection.
"""
struct FunctionRef
  name::Symbol
  file::Symbol
  avoid::Bool
end

# Convenience functions to make constructing these a little simpler
FunctionRef(name, file) = FunctionRef(name, file, false)
FunctionRef(name :: String, file, avoid) = FunctionRef(Symbol(name), file, avoid)
FunctionRef(name :: Symbol, file :: String, avoid) = FunctionRef(name, Symbol(file), avoid)

"""
    ReplayPoint(counter, check, module_list)

Represents a point where a `NaN` was injected during program execution.
"""
struct ReplayPoint
  counter::Int64
  check::Symbol
  stack::Vector{String}
end

"""
    Event

Struct representing some exceptional floating point event.

`category` options:

 - `:nan`
 - `:inf`

`evt_type` options:

 - `:injected`
 - `:gen`
 - `:prop`
 - `:kill`
"""
struct Event
  category::Symbol
  evt_type::Symbol
  op::String
  args::Array{Any}
  result::Any
  trace::StackTraces.StackTrace
end

using Base.StackTraces

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
"""
mutable struct Injector
  active::Bool
  odds::Int
  ninject::Int
  functions::Array{FunctionRef}
end

"""
    should_inject(i::Injector)

Return whether or not we should inject a `NaN`.

Decision process:

 - Checks whether or not the given injector is active.

 - Checks that there are some NaNs remaining to inject.

 - Checks that we're inside the scope of a function in `Injector.functions`.
   (Vacuously true if no functions given.)

 - Rolls an `Injector.odds`-sided die; if 1, inject a NaN, otherwise, don't do
   anything.
"""
function should_inject(i::Injector)::Bool
  if i.active && i.ninject > 0
    roll = rand(1:i.odds)

    if roll != 1
      return false
    end

    in_right_fn::Bool = if isempty(i.functions)
      true
    else
      in_functions = function (frame::StackTraces.StackFrame)
        file = Symbol(split(String(frame.file), ['/', '\\'])[end])
        fr = FunctionRef(frame.func, file)
        fr in i.functions
      end
      # TODO: check the head of the stacktrace to make sure it's all our files or standard library files
      # in_functions(stacktrace()[1])
      any(in_functions, stacktrace())
    end

    return roll == 1 && in_right_fn
  end

  return false
end

function decrement_injections(i::Injector)
  i.ninject = i.ninject - 1
end

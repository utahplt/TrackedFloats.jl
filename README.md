# FloatTracker.jl

Track `NaN` generation and propagation in your code.

Inspired by [Sherlogs.jl](https://github.com/milankl/Sherlogs.jl).

This repository originally lived in [Taylor Allred's repository](https://github.com/tcallred/FloatTracker.jl).

# Examples

Examples have been moved from this repository to an [example repository](https://github.com/utahplt/FloatTrackerExamples)—this allows us to keep the dependencies in this repository nice and light.

# Description

`FloatTracker.jl` is a library that provides three new types: `TrackedFloat16`, `TrackedFloat32`, and `TrackedFloat64`.
These behave just like their `FloatN` counterparts except that they detect and log instances of `NaN`.

If a `NaN` appears in a primitive floating point operation (such as `+`, `-`, `abs`, `sin` etc.), it generates an event:

- **GEN**: the operation generated a `NaN` as a result (e.g. `0.0 / 0.0 -> NaN`)
- **PROP**: the operation propagated a `NaN` from its arguments (e.g. `NaN + 2.0 -> NaN`)
- **KILL**: the operation had a `NaN` in its arguments but not in its result (e.g. `NaN > 1.0 -> false`)

These events are then stored in a buffered log and can be written out to a file during or after the execution of a program.

## Usage

 1. Call `using FloatTracker`; you may want to include functions like `enable_nan_injection` or `config_logger` or the like. (See below for more details.)
 2. Add additional customization to logging and injection.
 3. Wrap as many of your inputs in `TrackedFloatN` as you can

FloatTracker should take care of the rest!

Digging into step 2, there are two things that you can customize after initialization:

 - **The logger**

   Determines what and how events are captured and logged.

 - **The injector**

   Optional—default is to not inject. If you want to try injecting NaNs to fuzz your code, this is where you control when that happens.

*Coming soon: injection sessions to run a series of fuzzes.*

### Configuring the logger

```julia
# Set log file basename to "whatever"; all log files have the timestamp prepended
config_logger(filename="whatever")

# There are three kinds of events that we log:
#  - `:gen`  → when a NaN gets created from non-NaN arguments
#  - `:prop` → when a NaN argument leads to a NaN result
#  - `:kill` → when a NaN argument does *not* lead to a NaN result
#
# If logs are too noisy, we can disable some or all of the logs. For example,
# here we disable everything but NaN generation logging:
exclude_stacktrace([:prop,:kill])
```

Keyword arguments for `config_logger`:

 - `filename::String` Basename of the file to write logs to.

   Constructors automatically prefix the timestamp to the beginning of this
   basename so the logs are grouped together chronologically.

 - `buffersize::Int` Number of logs to buffer in memory before writing to file.

   Defaults to 1000. Decrease if you are crashing without getting the logs that you need.

 - `printToStdOut::Bool` Whether or not to write logs to STDOUT; defaults  to `false`.

 - `cstg::Bool` Write logs in CSTG format.

 - `cstgLineNum::Bool` Include the line number in CSTG output.

 - `cstgArgs::Bool` Include arguments to functions in CSTG output.

 - `maxLogs::Union{Int,Unbounded}` Maximum number of events to log; defaults to `Unbounded`.

 - `exclusions::Array{Symbol}` Events to not log; defaults to `[:prop]`.

### Configuring the injector

```julia
# Inject 2 NaNs
enable_nan_injection(2)

# Inject 2 NaNs, except when in the function "nope" in "way.jl"
enable_nan_injection(n_inject=2, functions=[FunctionRef("nope", "way.jl")])

# Enable recording of injections
record_injection("ft_recording") # this is just the file basename; will have timestamp prepended

# Enable recording playback
replay_injection("20230530T145830-ft_recording.txt")
```

Keyword arguments for `config_injector`:

 - `active::Boolean` inject only if true

 - `n_inject::Int` maximum number of NaNs to inject; gets decremented every time
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

## Example

```julia
using FloatTracker: TrackedFloat16, write_out_logs, config_logger, ft_init()

config_logger(filename="max")

function maximum(lst)
  max_seen = 0.0
  for x in lst
    if ! (x <= max_seen)
      max_seen = x              # swap if new val greater
    end
  end
  max_seen
end

function maximum2(lst)
  foldl(max, lst)
end

println("--- With less than ---")
res = maximum([TrackedFloat16(x) for x in [1, 5, 4, NaN, 4]]).val
println("Result: $(res)")
println()

println("--- With builtin max ---")
res2 = maximum2([TrackedFloat16(x) for x in [1, NaN, 4]]).val
println("Result: $(res2)")

write_out_logs()
```

This code shows two different implementations of a max-element function.
One uses the builtin `<` operator and the other uses Julia's `max` function. When encountering a `NaN` the `<` will "kill" it (always returning `false`) and the `max` function will "prop" it (always returning back the `NaN`).

We can see this in the log that produced by FloatTracker when running this file.

```
KILL 1.0,NaN -> < -> false
 	check_error at TrackedFloat.jl:14 [inlined]
	check_error at TrackedFloat.jl:13 [inlined]
	<(x::TrackedFloat16, y::TrackedFloat16) at TrackedFloat.jl:112
	maximum(lst::Vector{TrackedFloat16}) at max.jl:9
	top-level scope at max.jl:22

PROP 1.0,NaN -> max -> NaN
 	check_error at TrackedFloat.jl:14 [inlined]
	max(x::TrackedFloat16, y::TrackedFloat16) at TrackedFloat.jl:64
	BottomRF at reduce.jl:81 [inlined]
	_foldl_impl at reduce.jl:62 [inlined]
	foldl_impl at reduce.jl:48 [inlined]
	mapfoldl_impl at reduce.jl:44 [inlined]
	#mapfoldl#259 at reduce.jl:170 [inlined]
	mapfoldl at reduce.jl:170 [inlined]
	#foldl#260 at reduce.jl:193 [inlined]
	foldl at reduce.jl:193 [inlined]
	maximum2(lst::Vector{TrackedFloat16}) at max.jl:17

PROP NaN,4.0 -> max -> NaN
 	check_error at TrackedFloat.jl:14 [inlined]
	max(x::TrackedFloat16, y::TrackedFloat16) at TrackedFloat.jl:64
	BottomRF at reduce.jl:81 [inlined]
	_foldl_impl at reduce.jl:62 [inlined]
	foldl_impl at reduce.jl:48 [inlined]
	mapfoldl_impl at reduce.jl:44 [inlined]
	#mapfoldl#259 at reduce.jl:170 [inlined]
	mapfoldl at reduce.jl:170 [inlined]
	#foldl#260 at reduce.jl:193 [inlined]
	foldl at reduce.jl:193 [inlined]
	maximum2(lst::Vector{TrackedFloat16}) at max.jl:17
```
This is an example of a program where two different implementations can result in a different answer when dealing with `NaN` in the input. In a larger program, the presence of `NaN` can produce incorrect results.
This tool may be useful for debugging those sorts of issues.

## Known operations that can kill a NaN

```
1.0 ^  NaN → 1.0
NaN ^  0.0 → 1.0
1.0 <  NaN → false
1.0 >  NaN → false
1.0 <= NaN → false
1.0 >= NaN → false
```

Most of the time comparison operators are what kill a NaN. But `^` can kill NaNs too.

# Recording NaN injections

FloatTracker allows you to fuzz code and inject NaNs wherever a `TrackedFloat` type is used. Moreover, you can record these injections to rerun injections.

**ACHTUNG:** it is critical that inputs to the program be exactly the same for recording and replaying to be consistent. The recordings are sensitive to the number of times a floating point operation is hit.

**TODO:** describe how to set up a recording and replay it.

## Recording sessions

Sometimes we want to inject NaNs throughout the program. We can create a "recording session" that will before each injection check if that point has been tried before. If it has, we move on and try again at the next injection point.

We can tell FloatTracker what we consider to be identical injection points. **TODO:** how *do* we tell FloatTracker what we consider to be the same and not the same? Function boundaries?

## Recording internals

During recording and replaying, we increment a counter each time a floating point operation happens. This doesn't add much overhead [*citation needed*] since we're already intercepting each of the floating point calls anyway—but it explains why we need to make sure our programs are deterministic before recording and replaying.

Injection points are saved to a *recording file*, where each line denotes an injection point. Example:

```
42, solve.jl, OrdinaryDiffEq::solve OrdinaryDiffEq::do_it Finch::make_it_so
```

The first field `42` is the injection point, or the nth time a floating point operation was intercepted by FloatTracker. The second field `solve.jl` acts as a little sanity check: this is the first non-FloatTracker file off of the stack trace. After that comes a list of module names paired with the function on the call stack.

# Generating CSTGs

Get the [CSTG](https://github.com/utahplt/cstg) code.

Run a program that uses TrackedFloats (e.g. from the [example repository](https://github.com/utahplt/FloatTrackerExamples)).
By default, a file with `*error_log*` in its name should appear.

Generate a graph using the error log:

```
./path/to/tracerSum *-program_error_log.txt output_basename
# prints many lines to stdout
```

Open `output_basename.pdf` to see the CSTG.


# Running tests

You can run tests one of two ways:

```
$ julia --project=. test/runtests.jl
```

or via the Julia shell:

```
julia> ]             # enter the package shell
pkg> activate .
(FloatTracker) pkg> test
```


# License

MIT License

# Authors

 - [Taylor Allred](https://github.com/tcallred)
 - [Ashton Wiersdorf](https://github.com/ashton314)
 - [Ben Greenman](https://github.com/bennn)

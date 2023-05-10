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

## Example

```julia
using FloatTracker: TrackedFloat16, write_out_logs, set_logger

set_logger(filename="max", buffersize=1)

function maximum(lst)
  curr_max = 0.0
  for x in lst
    if curr_max < x 
      curr_max = x
    end
  end
  curr_max
end

function maximum2(lst)
  foldl(max, lst)
end
  
println("--- With less than ---")
# res = maximum([1, NaN, 4])
res = maximum([TrackedFloat16(x) for x in [1, NaN, 4]]).val
println("Result: $(res)")
println()

println("--- With builtin max ---")
# res2 = maximum2([1, NaN, 4])
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

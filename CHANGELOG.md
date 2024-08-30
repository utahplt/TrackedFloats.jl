# Changelog

We strive to follow [SemVer](https://semver.org/) conventions. Per [item 4 in the spec](https://semver.org/#semantic-versioning-specification-semver), versions prior to `1.0.0` have new features and/or breaking changes with every update to the minor version number. Patch numbers will continue to be backwards-compatible with a given minor version number.

That said, this is research software, so expect some instability as we aim first and foremost to push the boundaries of what is possible.

## 1.0.1

Enable Inf injection (issue [#41](https://github.com/utahplt/TrackedFloats.jl/issues/41))

## 1.0.0

Release the package!

We are pretty happy with where the API is at this point, and we want to release a good initial version before JuliaCon 2023. No major changes since 0.6.0.

## 0.6.0

### Fixed

 - Bug: setting `maxLogs` to `Unbounded` would fail to write logs to file.

### Changed

 - Rename `write_out_logs` → `tf_flush_logs`.

## 0.5.1

Fix `maxLogs` parameter to only count towards events not excluded by `exclude_stacktrace`.

## 0.5.0

### Added

Tracks `Inf` as well as `NaN` kills/gens. Logging controls are still coarse-grained: e.g. excluding `:props` excludes props to both. No `Inf` injections at this time, just tracking.

## 0.4.0

This release includes a shiny new CI pipeline. It's pretty bare-bones right now, but it does run our (sparse) set of unit tests automatically, so that's nice!

### Added

Basic support for complex numbers. All you need to do is this:

```julia
TrackedFloat64(1.0 + 2.0im)
```

Note that support is *rudimentary* for now—don't expect too much, and let us know if you need any more functionality than what is currently working.

### Changed

Improved the last-ditch effort to extract the module name from a stack frame. Note that in order for the `libraries` exclusion option to work, the libraries here MUST NOT have the `.jl` suffix. This is noted in the documentation for `InjectorConfig`.

## 0.3.0

### Added

Event limit in logger works: set `maxLogs` to control how many events get logged. TrackedFloats stops collecting stack traces after this, so should run much faster once the threshold has been hit. Defaults to `Unbounded()`.

## 0.2.0

### Added

Logger config:

 - `allErrors` controls whether or not to print to the catch-all `*_error_log.txt` file. (Now `false` by default.)
 - `maxFrames` controls how many stack frames get printed per event. (`Unbounded` by default.)

### Replaced functions

Rename to remove the `!` from functions:

 - `config_logger!` → `config_logger`
 - `config_injector!` → `config_injector`
 - `config_session!` → `config_session`

Similar and bigger function renames:

 - `enable_nan_injection!` → `enable_nan_injection`
 - `disable_nan_injection!` → `disable_nan_injection`
 - `set_exclude_stacktrace!` → `exclude_stacktrace`
 - `enable_injection_recording!` → `record_injection`
 - `set_injection_replay!` → `replay_injection`

## 0.1.0

Massive configuration API rewrite. This should make it easier to maintain and extend in the future.

### New functions

 - `enable_nan_injection!(n_inject = 1)`
 - `disable_nan_injection!()`
 - `enable_injection_recording!(recording_file::String = "tf_recording")`
 - `set_injection_replay!(replay_file::String)`

### Replaced functions

 - `set_logger(kwargs...)` → `config_logger!(kwargs...)`

   Continues to accept the same keyword arguments as the original function.

 - `set_inject_nan(args...)` → `config_injector!(kwargs...)`

   Instead of positional arguments, the injector function now takes keyword arguments. New keyword arguments and their defaults:
   
    + `should_inject::Bool=true`
    + `odds::Int64=10`
    + `n_inject::Int64=1`
    + `functions=[]`
    + `libraries=[]`
    + `replay=""`
    + `record=""`

   See also the new convenience functions that break out some of the roles of this function into smaller, semantic chunks.

 - `set_exclude_stacktrace([:prop...])` → `set_exclude_stacktrace!([:prop...])`

   Convenience function; you can also set the exclusions by using a keyword argument to `config_logger!`.

## 0.0.0

Beginning of change tracking.

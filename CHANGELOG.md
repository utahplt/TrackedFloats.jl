# Changelog

We strive to follow [SemVer](https://semver.org/) conventions. Per [item 4 in the spec](https://semver.org/#semantic-versioning-specification-semver), until the API stabilizes and we make an official `1.0.0` release, expect new features and/or breaking changes with every update to the minor version number. Patch numbers will continue to be backwards-compatible with a given minor version number.

That said, this is research software, so expect some instability as we aim first and foremost to push the boundaries of what is possible.

## 0.2.0

Rename to remove the `!` from functions:

 - `config_logger!` → `config_logger`
 - `config_injector!` → `config_injector`
 - `config_session!` → `config_session`

TODO: need to still update other ! functions

## 0.1.0

Massive configuration API rewrite. This should make it easier to maintain and extend in the future.

### New functions

 - `enable_nan_injection!(n_inject = 1)`
 - `disable_nan_injection!()`
 - `enable_injection_recording!(recording_file::String = "ft_recording")`
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

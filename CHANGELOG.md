# Changelog

## 2023-05-30

Massive configuration API rewrite. This should make it easier to maintain and extend in the future.

### New functions

 - `enable_nan_injection!(n_inject = 1)`
 - `disable_nan_injection!()`
 - `enable_injection_recording!(recording_file::String = "ft_recording")`
 - `set_injection_replay!(replay_file::String)`

### Replaced functions

 - `set_logger(kwargs...)` → `set_logger_config!(kwargs...)`

   Continues to accept the same keyword arguments as the original function.

 - `set_inject_nan(args...)` → `set_injector_config!(kwargs...)`

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

   Convenience function; you can also set the exclusions by using a keyword argument to `set_logger_config!`.

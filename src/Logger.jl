# Constructors

mutable struct LogBuffer
  events::Array{Event}
end

log_buffer = LogBuffer([])

function log_event(evt::Event)
  push!(log_buffer.events, evt)

  if ft_config.log.printToStdOut
    println(to_string(evt))
  end
  if length(log_buffer.events) >= ft_config.log.buffersize
    if isa(ft_config.log.maxLogs, Unbounded) || (isa(ft_config.log.maxLogs, Int) && ft_config.log.maxLogs > 0)
      ft_flush_logs()
      if isa(ft_config.log.maxLogs, Int)
        ft_config.log.maxLogs -= length(log_buffer.events)
      end
    end
    log_buffer.events = []
  end
end

function ft_flush_logs()
  if ft_config.log.allErrors
    write_error_logs()
  end

  if ft_config.log.cstg
    write_logs_for_cstg()
  end
end

function print_log()
  for e in log_buffer.events
    println(e)
  end
end

function write_error_logs()
  if length(log_buffer.events) > 0
    open(errors_file(), "a") do file
      for e in log_buffer.events
        write(file, "$(to_string(e))\n\n")
      end
    end
  end
end

function write_logs_for_cstg()
  injects  = filter(e -> e.evt_type == :injected, log_buffer.events)
  gens     = filter(e -> e.evt_type == :gen, log_buffer.events)
  props    = filter(e -> e.evt_type == :prop, log_buffer.events)
  kills    = filter(e -> e.evt_type == :kill, log_buffer.events)

  if length(injects) > 0
    open(injects_file(), "a") do file
      write_events(file, injects)
    end
  end
  if length(gens) > 0
    open(gens_file(), "a") do file
      write_events(file, gens)
    end
  end
  if length(props) > 0
    open(props_file(), "a") do file
      write_events(file, props)
    end
  end
  if length(kills) > 0
    open(kills_file(), "a") do file
      write_events(file, kills)
    end
  end
end

function format_cstg_stackframe(sf::StackTraces.StackFrame, frame_args::Vector{} = [])
  func = String(sf.func)        # FIXME/TODO: can we make sure the function name here is well-formed for CSTG's digestion?
  linfo = "$(sf.linfo)"
  args = if ft_config.log.cstgArgs && isempty(frame_args)
    if isa(sf.linfo, Core.CodeInfo)
      "$(sf.linfo.code[1])"
    else
      mx = match(r"^.+\((.*?)\)", linfo)
      "($(!isnothing(mx) && length(mx) > 0 ? mx[1] : ""))"
    end
  elseif ft_config.log.cstgArgs
    "($frame_args)"
  else
    ""
  end

  linenum = if ft_config.log.cstgLineNum
    ":$(sf.line)"
  else
    ""
  end

  "$(func)$(args) at $(sf.file)$(linenum)"
end

function category(e::Event)
  if e.category == :nan
    "NaN"
  elseif e.category == :inf
    "Inf"
  else
    ""
  end
end

function write_events(file, events::Vector{Event})
  for e in events
    if length(e.trace) > 0

      # correct args in top frame so it's the values not just the traces
      write(file, "[$(category(e))] $(format_cstg_stackframe(e.trace[1], e.args))\n")

      # write remaining frames up to ftv-config.log.maxFrames
      for sf in e.trace[(isa(ft_config.log.maxFrames, Unbounded) ? (2:end) : (2:(ft_config.log.maxFrames + 1)))]
        write(file, "$(format_cstg_stackframe(sf))\n")
      end

      write(file, "\n")
    end
  end
end

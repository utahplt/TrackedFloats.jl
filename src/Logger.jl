using Dates

mutable struct LoggerConfig
  filename::String
  buffersize::Int
  printToStdOut::Bool
  outputCSTG::Bool
  cstgLineNum::Bool
  cstgArgs::Bool
end

log_config = LoggerConfig("default", 5, false, false, true, true)

mutable struct Logger
  events::Array{Event}
end

logger = Logger([])

function set_logger(; filename="default", buffersize=5, print=false, cstg=false, cstgLineNum=true, cstgArgs=true)
  time = now().instant.periods.value % 99999999
  log_config.filename = "$(filename)_$(time)"
  log_config.buffersize = buffersize
  log_config.printToStdOut = print
  log_config.outputCSTG = cstg
  log_config.cstgLineNum = cstgLineNum
  log_config.cstgArgs = cstgArgs
  return log_config.filename
end

function log_event(evt::Event)
  push!(logger.events, evt)
  if log_config.printToStdOut
    println(to_string(evt))
  end
  if length(logger.events) >= log_config.buffersize
    write_out_logs()
    logger.events = []
  end
end

function write_out_logs()
  write_log_to_file()
  if log_config.outputCSTG
    write_logs_for_cstg()
  end
end

function print_log()
  for e in logger.events
    println(e)
  end
end

function write_log_to_file()
  if length(logger.events) > 0
    open("$(log_config.filename)_error_log.txt", "a") do file
      for e in logger.events
        write(file, "$(to_string(e))\n\n")
      end
    end
  end
end

function format_cstg_stackframe(sf::StackTraces.StackFrame)
  if log_config.cstgArgs && log_config.cstgLineNum
    return "$(sf)"
  end
  func = String(sf.func)
  file = split(String(sf.file), ['/', '\\'])[end]
  linfo = "$(sf.linfo)"
  args = if log_config.cstgArgs
    "($(split(linfo, '(')[end])"
  else
    ""
  end
  linenum = if log_config.cstgLineNum
    ":$(sf.line)"
  else
    ""
  end

  "$(func)$(args) at $(file)$(linenum)"
end

function write_events(file, events)
  for e in events
    if length(e.trace) > 0
      for sf in e.trace
        write(file, "$(format_cstg_stackframe(sf))\n")
      end
      write(file, "\n")
    end
  end
end

function write_logs_for_cstg()
  injects = filter(e -> e.evt_type == :injected, logger.events)
  gens = filter(e -> e.evt_type == :gen, logger.events)
  props = filter(e -> e.evt_type == :prop, logger.events)
  kills = filter(e -> e.evt_type == :kill, logger.events)
  if length(injects) > 0
    open("$(log_config.filename)_cstg_injects.txt", "a") do file
      write_events(file, injects)
    end
  end
  if length(gens) > 0
    open("$(log_config.filename)_cstg_gens.txt", "a") do file
      write_events(file, gens)
    end
  end
  if length(props) > 0
    open("$(log_config.filename)_cstg_props.txt", "a") do file
      write_events(file, props)
    end
  end
  if length(kills) > 0
    open("$(log_config.filename)_cstg_kills.txt", "a") do file
      write_events(file, kills)
    end
  end
end

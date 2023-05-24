using Dates

mutable struct LoggerConfig
  filename::String
  buffersize::Int
  printToStdOut::Bool
  outputCSTG::Bool
  cstgLineNum::Bool
  cstgArgs::Bool
  maxLogs::Union{Int,AbstractString}
end

# Constructors
# LoggerConfig() =
#   LoggerConfig("default", 1000)
# LoggerConfig(filename, buff_size) =
#   LoggerConfig(filename=filename, buffersize=buff_size, print=false, cstg=false, cstgLineNum=true, cstgArgs=true)
# LoggerConfig(filename, buff_size, cstg) =
#   LoggerConfig(filename=filename, buffersize=buff_size, print=false, cstg=cstg, cstgLineNum=true, cstgArgs=true)
# LoggerConfig(; filename="default", buffersize=1000, print=false, cstg=false, cstgLineNum=true, cstgArgs=true) =
#   LoggerConfig(filename, buffersize, print, cstg, cstgLineNum, cstgArgs)

log_config = LoggerConfig("default", 1000, false, false, true, true, "unbounded")

mutable struct Logger
  events::Array{Event}
end

logger = Logger([])

function set_logger(; filename="default", buffersize=1000, print=false, cstg=false, cstgLineNum=true, cstgArgs=true, maxLogs="unbounded")
  now_str = Dates.format(now(), "yyyymmddHHMMss")
  log_config.filename = "$(now_str)-$(filename)"
  log_config.buffersize = buffersize
  log_config.printToStdOut = print
  log_config.outputCSTG = cstg
  log_config.cstgLineNum = cstgLineNum
  log_config.cstgArgs = cstgArgs
  log_config.maxLogs = maxLogs
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

"""
    write_log_to_file()

Flush output logs.
"""
function write_log_to_file()
  if length(logger.events) > 0
    open("$(log_config.filename)_error_log.txt", "a") do file
      for e in logger.events
        write(file, "$(to_string(e))\n\n")
      end
    end
  end
end

function format_cstg_stackframe(sf::StackTraces.StackFrame, frame_args::Vector{} = [])
  # if log_config.cstgArgs && log_config.cstgLineNum && isempty(frame_args)
  #   return "$(sf)"
  # end
  func = String(sf.func)        # FIXME/TODO: can we make sure the function name here is well-formed for CSTG's digestion?
  linfo = "$(sf.linfo)"
  args = if log_config.cstgArgs && isempty(frame_args)
    if isa(sf.linfo, Core.CodeInfo)
      "$(sf.linfo.code[1])"
    else
      mx = match(r"^.+\((.*?)\)", linfo)
      "($(!isnothing(mx) && length(mx) > 0 ? mx[1] : ""))"
    end
  elseif log_config.cstgArgs
    "($frame_args)"
  else
    ""
  end

  println("linfo: $linfo; args: $args")

  linenum = if log_config.cstgLineNum
    ":$(sf.line)"
  else
    ""
  end

  "$(func)$(args) at $(sf.file)$(linenum)"
end

function write_events(file, events::Vector{Event})
  for e in events
    if length(e.trace) > 0

      # correct args in top frame so it's the values not just the traces
      write(file, "$(format_cstg_stackframe(e.trace[1], e.args))\n")

      # write remaining frames
      for sf in e.trace[2:end]
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

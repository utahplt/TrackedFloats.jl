# Constructors

mutable struct Logger
  events::Array{Event}
end

logger = Logger([])

function log_event(evt::Event)
  push!(logger.events, evt)
  if ft_config.log.printToStdOut
    println(to_string(evt))
  end
  if length(logger.events) >= ft_config.log.buffersize
    write_out_logs()
    logger.events = []
  end
end

function write_out_logs()
  write_log_to_file()
  if ft_config.log.cstg
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
    open("$(ft_config.ses.sessionId)-$(ft_config.log.filename)_error_log.txt", "a") do file
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

  # println("linfo: $linfo; args: $args")

  linenum = if ft_config.log.cstgLineNum
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
    open("$(ft_config.ses.sessionId)-$(ft_config.log.filename)_cstg_injects.txt", "a") do file
      write_events(file, injects)
    end
  end
  if length(gens) > 0
    open("$(ft_config.ses.sessionId)-$(ft_config.log.filename)_cstg_gens.txt", "a") do file
      write_events(file, gens)
    end
  end
  if length(props) > 0
    open("$(ft_config.ses.sessionId)-$(ft_config.log.filename)_cstg_props.txt", "a") do file
      write_events(file, props)
    end
  end
  if length(kills) > 0
    open("$(ft_config.ses.sessionId)-$(ft_config.log.filename)_cstg_kills.txt", "a") do file
      write_events(file, kills)
    end
  end
end

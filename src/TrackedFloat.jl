abstract type AbstractTrackedFloat <: AbstractFloat end

@inline function check_error(fn, injected::Bool, result, args...)
  if any(v -> isfloaterror(v), [args..., result])
    # args is a tuple; we call `collect` to get a Vector without promoting the types
    if isa(ft_config.log.maxLogs, Int) && ft_config.log.maxLogs > 0
      # We do not decrement at this point: that happens in the logger so we get
      # the right amount of logs of the *kind* that we want.
      map(log_event, event(string(fn), collect(args), result, injected))
    elseif isa(ft_config.log.maxLogs, Unbounded)
      map(log_event, event(string(fn), collect(args), result, injected))
    end
  end
end

@inline function run_or_inject(fn, args...)
  if should_inject(ft_config.inj)
    decrement_injections(ft_config.inj)
    (NaN, true)
  else
    (fn(args...), false)
  end
end

for TrackedFloatN in (:TrackedFloat16, :TrackedFloat32, :TrackedFloat64)
  # FloatN is the base float type derived from TrackedFloatN
  @eval FloatN = $(Symbol("Float", string(TrackedFloatN)[end-1:end]))

  @eval begin
    struct $TrackedFloatN <: AbstractTrackedFloat
      val::$FloatN
    end

    # Could we be loosing our tracking ability if a program uses one of these to
    # cast a float? Would we want to have our own explicit TrackedFloat→Float
    # unwrapper?
    Base.Float64(x::$TrackedFloatN) = Float64(x.val)
    Base.Float32(x::$TrackedFloatN) = Float32(x.val)
    Base.Float16(x::$TrackedFloatN) = Float16(x.val)
    Base.Int64(x::$TrackedFloatN) = Int64(x.val)
    Base.Int32(x::$TrackedFloatN) = Int32(x.val)
    Base.Int16(x::$TrackedFloatN) = Int16(x.val)

    Base.bitstring(x::$TrackedFloatN) = bitstring(x.val)
    Base.show(io::IO,x::$TrackedFloatN) = print(io, $TrackedFloatN,"(",string(x.val),")")

    # $TrackedFloatN(x::AbstractFloat) = $TrackedFloatN(x)
    # $TrackedFloatN(x::Integer) = $TrackedFloatN(x)
    $TrackedFloatN(x::Rational{}) = $TrackedFloatN($FloatN(x))
    $TrackedFloatN(x::$TrackedFloatN) = $TrackedFloatN(x.val)
    $TrackedFloatN(x::Bool) = $TrackedFloatN($FloatN(x))

    # Tracking a Complex struct returns a complex number with component parts
    # wrapped in a TrackedFloat struct
    $TrackedFloatN(x::Complex{}) = tf_track_complex(x)

    Base.promote_rule(::Type{<:Integer},::Type{$TrackedFloatN}) = $TrackedFloatN
    Base.promote_rule(::Type{Float64},::Type{$TrackedFloatN}) = $TrackedFloatN
    Base.promote_rule(::Type{Float32},::Type{$TrackedFloatN}) = $TrackedFloatN
    Base.promote_rule(::Type{Float16},::Type{$TrackedFloatN}) = $TrackedFloatN
    Base.promote_rule(::Type{Bool},::Type{$TrackedFloatN}) = $TrackedFloatN
  end

  # Helper functions for working with complex numbers
  @eval function tf_to_complex(real::$TrackedFloatN, imaginary::$TrackedFloatN=$TrackedFloatN(0.0))
    Complex(real, imaginary)
  end

  @eval function tf_track_complex(c::Complex{$FloatN})
    Complex($TrackedFloatN(c.re), $TrackedFloatN(c.im))
  end

  @eval function tf_untrack_complex(c::Complex{$TrackedFloatN})
    Complex(c.re.val, c.im.val)
  end

  # Use this where an int got wrapped with a TrackedFloat
  @eval function trunc_if_int(y::$TrackedFloatN)
    t = trunc(Int, y.val)
    if abs(y.val - t) < floatmin(y)
      return t
    else
      error("Unable to safely truncate $y into an int")
    end
  end

  number_types = (:Number, :Integer, :Float16, :Float32, :Float64)
  complex_types = (:ComplexF16, :ComplexF32, :ComplexF64)

  for NumType in number_types
    @eval function Base.ldexp(x::$NumType, y::$TrackedFloatN)
      y_as_int = trunc_if_int(y)
      (r, injected) = run_or_inject(ldexp, x, y_as_int)
      check_error(ldexp, injected, r, x, y_as_int)
      $TrackedFloatN(r)
    end
  end

  # Binary operators
  for O in (:(+), :(-), :(*), :(/), :(^), :min, :max, :rem)
    @eval function Base.$O(x::$TrackedFloatN,y::$TrackedFloatN)
      (r, injected) = run_or_inject($O, x.val, y.val)
      check_error($O, injected, r, x.val, y.val)
      $TrackedFloatN(r)
    end

    @eval function Base.$O(x::Complex{$TrackedFloatN}, y::Complex{$TrackedFloatN})
      xx = tf_untrack_complex(x)
      yy = tf_untrack_complex(y)
      (r, injected) = run_or_inject($O, xx, yy)
      check_error($O, injected, r, xx, yy)
      $TrackedFloatN(r)
    end

    @eval function Base.$O(x::Complex{}, y::$TrackedFloatN)
      xx = tf_untrack_complex(x)
      (r, injected) = run_or_inject($O, xx, y.val)
      check_error($O, injected, r, xx, y.val)
      $TrackedFloatN(r)
    end

    @eval function Base.$O(x::$TrackedFloatN, y::Complex{})
      yy = tf_untrack_complex(y)
      (r, injected) = run_or_inject($O, x.val, yy)
      check_error($O, injected, r, x.val, yy)
      $TrackedFloatN(r)
    end

    # Hack to appease type dispatch
    for NumType in tuple(:Bool, number_types...)
      @eval function Base.$O(x::$NumType, y::$TrackedFloatN)
        (r, injected) = run_or_inject($O, x, y.val)
        check_error($O, injected, r, x, y.val)
        $TrackedFloatN(r)
      end

      @eval function Base.$O(x::$TrackedFloatN, y::$NumType)
        (r, injected) = run_or_inject($O, x.val, y)
        check_error($O, injected, r, x.val, y)
        $TrackedFloatN(r)
      end
    end
  end

  # Base.decompose seems to be an internal function. Moreover, it always returns
  # a tuple of integers. See function def:
  # ~/.asdf/installs/julia/1.8.5/share/julia/base/float.jl
  #
  # Because of this, we treat any call to decompose with a NaN as a kill event.

  @eval function Base.decompose(x::$TrackedFloatN)
    if isnan(x)
      map(log_event, event("decompose", [x], (0,0,0))) # Log the kill
    end
    Base.decompose(x.val)
  end

  # Unary operators
  for O in (:(-), :(+),
            :sign,
            :prevfloat, :nextfloat,
            :round, :trunc, :ceil, :floor,
            :inv, :abs, :sqrt, :cbrt,
            :exp, :expm1, :exp2, :exp10,
            :exponent,
            :log, :log1p, :log2, :log10,
            :rad2deg, :deg2rad, :mod2pi, :rem2pi,
            :sin, :cos, :tan, :csc, :sec, :cot,
            :asin, :acos, :atan, :acsc, :asec, :acot,
            :sinh, :cosh, :tanh, :csch, :sech, :coth,
            :asinh, :acosh, :atanh, :acsch, :asech, :acoth,
            :sinc, :sinpi, :cospi,
            :sind, :cosd, :tand, :cscd, :secd, :cotd,
            :asind, :acosd, :atand, :acscd, :asecd, :acotd,
            )
    @eval function Base.$O(x::$TrackedFloatN)
      (r, injected) = run_or_inject($O, x.val)
      check_error($O, injected, r, x.val)
      $TrackedFloatN(r)
    end
  end

  # Type-based functions
  for fn in (:floatmin, :floatmax, :eps)
    @eval Base.$fn(::Type{$TrackedFloatN}) = $fn($FloatN)
  end

  @eval Base.one(::Type{$TrackedFloatN}) = $TrackedFloatN(one($FloatN))

  @eval function Base.trunc(t::Type, x::$TrackedFloatN)
    r = trunc(t, x.val)
    check_error(:trunc, false, r, x.val)
    r
  end

  @eval function Base.round(x::$TrackedFloatN, digits::RoundingMode)
    r = round(x.val, digits)
    check_error(:round, false, r, x.val)
    $TrackedFloatN(r)
  end


  for O in (:isnan, :isinf, :issubnormal)
    @eval function Base.$O(x::$TrackedFloatN)
      r = $O(x.val)
      check_error($O, false, r, x.val)
      r
    end
  end

  for O in (:(<), :(<=), :(==))
    @eval function Base.$O(x::$TrackedFloatN, y::$TrackedFloatN)
      r = $O(x.val, y.val)
      check_error($O, false, r, x.val, y.val)
      r
    end
  end
end                             # for TrackedFloatN

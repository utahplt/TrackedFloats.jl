abstract type AbstractTrackedFloat <: AbstractFloat end

for TrackedFloatN in (:TrackedFloat16, :TrackedFloat32, :TrackedFloat64)
  # Helper functions for working with complex numbers
  println("tf_to_complex")
  println("tf_track_complex")
  println("tf_untrack_complex")

  # Use this where an int got wrapped with a TrackedFloat
  println("trunc_if_int")

  number_types = (:Number, :Integer, :Float16, :Float32, :Float64)
  complex_types = (:ComplexF16, :ComplexF32, :ComplexF64)

  for NumType in number_types
    println("Base")
  end

  # Binary operators
  for O in (:(+), :(-), :(*), :(/), :(^), :min, :max, :rem)
    println("Base")
    println("Base")
    println("Base")
    println("Base")

    # Hack to appease type dispatch
    for NumType in tuple(:Bool, number_types...)
      println("Base")
      println("Base")
    end
  end

  # Base.decompose seems to be an internal function. Moreover, it always returns
  # a tuple of integers. See function def:
  # ~/.asdf/installs/julia/1.8.5/share/julia/base/float.jl
  #
  # Because of this, we treat any call to decompose with a NaN as a kill event.

  println("Base")

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
    println("$O")
  end

  # Type-based functions
  for fn in (:floatmin, :floatmax, :eps)
    println("$fn")
  end

  println("one")
  println("Base")
  println("Base")


  for O in (:isnan, :isinf, :issubnormal)
    println("Base")
  end

  for O in (:(<), :(<=), :(==))
    println("Base")
  end
end                             # for TrackedFloatN

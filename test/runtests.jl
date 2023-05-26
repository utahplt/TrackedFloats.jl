using Test

println("--- config API tests ---")
include("config_api_tests.jl")

println("--- injector tests ---")
include("injector_tests.jl")

println("--- recording session tests ---")
include("recording_session_tests.jl")

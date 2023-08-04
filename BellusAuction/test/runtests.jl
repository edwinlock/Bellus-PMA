using BellusAuction
using Test

@testset "All tests" begin

	@testset "Blackbox tests" begin
		include("blackbox_tests.jl")
	end

end
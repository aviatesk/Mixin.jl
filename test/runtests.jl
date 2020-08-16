using Mixin
using Test

@testset "Mixin.jl" begin
    get_rettyp(f, argtypes) = last(first(code_typed(f, argtypes)))

    # basic
    @interface struct Ty1
        con::Int
        abs::Union{Symbol,String}
        any
   end

    @mixin struct Ty11 <: Ty1
        con::Int
        abs::Union{Symbol,String}
        any
    end

    @mixin struct Ty12 <: Ty1
        con::Int
        abs::Symbol
        any
        additional::Symbol
        function Ty12(con, args...)
            con ≤ 0 && error("con should be positive for some reason")
            new(con, args...)
        end
    end

    @test get_rettyp(ary->first(ary).con, (Vector{Ty1},)) == Int
    @test get_rettyp(ary->first(ary).abs, (Vector{Ty1},)) == Union{Symbol,String}

    # FIXME: we want to check against AssertionError if possible

    # lack of required field
    @test_throws LoadError macroexpand(@__MODULE__, :(
    @mixin struct Ty13 <: Ty1
        con::Int
        any
    end
    ))

    # invalid typing
    @test_throws LoadError macroexpand(@__MODULE__, :(
    @mixin struct Ty14 <: Ty1
        con::Int
        abs::Int
        any
    end
    ))
end

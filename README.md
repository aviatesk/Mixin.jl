## mixin for julia

Mixin.jl provides utility macro to declare interfaces (`@interface`) and define types that mixes in interface (`@mixin`).
They will also help julia infer the types of interfaces, even though they're actually represented as abstract types.

### examples

```julia
julia> using Mixin

# declare interface; this actually defines `Ty1` as an abstract type
julia> @interface struct Ty1
           con::Int
           abs::Union{Symbol,String}
           any
       end

# define mixins
julia> @mixin struct Ty11 <: Ty1
           con::Int
           abs::Union{Symbol,String}
           any
       end

julia> @mixin struct Ty12 <: Ty1
           con::Int
           abs::Symbol # field can be subtype of the type declared in the interface
           any
           additional::Symbol  # non-mixin additional field can be declaraed
           # inner constructor etc should work as for usual struct declaration
           function Ty12(con, args...)
               con ≤ 0 && error("con should be positive for some reason")
               new(con, args...)
           end
       end

# @mixin asserts a mixin declaration
julia> @mixin struct Ty13 <: Ty1
           con::Int
           any
       end
ERROR: LoadError: AssertionError: interface Ty1 requires abs::Union{String, Symbol}
Stacktrace:
 ...

# @mixin asserts a mixin declaration
julia> @mixin struct Ty14 <: Ty1
           con::Int
           abs::Int
           any
       end
ERROR: LoadError: AssertionError: mixin field Ty1.abs is expected to be declared as subtype of Union{String, Symbol} but declared as abs::Int64
Stacktrace:
 ...

# now julia can infer types for fields of interfaces (even though they're actually abstract types)
julia> code_typed(ary->first(ary).con, (Vector{Ty1},))
1-element Vector{Any}:
 CodeInfo(
1 ─      Base.arraysize(ary, 1)::Int64
│   %2 = Base.arrayref(true, ary, 1)::Ty1
│   %3 = Mixin.getfield(%2, :con)::Any
│        Core.typeassert(%3, Main.Int)::Int64
│   %5 = π (%3, Int64)
└──      return %5
) => Int64
```

### acknowledgement

The basic idea of the implementation came from [this PR by @timholy](https://github.com/JuliaLang/julia/pull/36323).

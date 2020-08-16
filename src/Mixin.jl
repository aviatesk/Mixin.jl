module Mixin

using Base.Meta:
    isexpr

macro interface(ex)
    @assert isexpr(ex, :struct, 3) "struct expression should be given"

    _, typedecl, body = ex.args
    T = get_type_sym(typedecl)
    flddecls = get_fielddecls(body)

    getter = create_getter(T, flddecls)
    actualtypedecl = :(abstract type $(typedecl) end)
    create_mixin_asserter(__module__, actualtypedecl, flddecls)

    return quote
        $(actualtypedecl) # already evaled so actually not needed to be returned, but just for explicit macro expansion
        $(getter) # define getter in user code
    end
end

get_type_sym(typedecl) = isexpr(typedecl, :(<:)) ? first(typedecl.args) : typedecl
get_fielddecls(body) = return filter(body.args) do x
    isexpr(x, :(::)) || x isa Symbol
end

get_field_sym(flddecl) = isexpr(flddecl, :(::)) ? first(flddecl.args) : flddecl
get_type(mod, flddecl) = isexpr(flddecl, :(::)) ? Core.eval(mod, last(flddecl.args)) : Any

function create_getter(T, flddecls)
    body = Expr(:block)

    for flddecl in flddecls
        isexpr(flddecl, :(::)) || continue # untyped

        sig, ty = flddecl.args
        get_typed_ex = :(if sym === $(QuoteNode(sig))
            return getfield(obj, sym)::$(esc(ty))
        end)
        push!(body.args, get_typed_ex)
    end

    fallback = :(return getfield(obj, sym))
    push!(body.args, fallback)

    return :(function Base.getproperty(obj::$(esc(T)), sym::Symbol)
        $(body)
    end)
end

function assert_mixin end # will be overloaded on each interface declaration

function create_mixin_asserter(defmod, actualtypedecl, flddecls)
    # get actual types
    Core.eval(defmod, actualtypedecl)
    T = get_type_sym(first(actualtypedecl.args))
    Ty = Core.eval(defmod, T)
    fldsym2ty_mixin = Dict(
        get_field_sym(flddecl) => get_type(defmod, flddecl)
        for flddecl in flddecls
    )

    asserter = :(function assert_mixin(mod, interface::$(Type{Ty}), body)
        flddecls = $(get_fielddecls)(body)
        fldsym2ty = Dict(
            $(get_field_sym)(flddecl) => $(get_type)(mod, flddecl)
            for flddecl in flddecls
        )

        foreach($(fldsym2ty_mixin)) do (fldsym_mixin, ty_mixin)
            @assert haskey(fldsym2ty, fldsym_mixin) string("interface ", $(Ty), " requires ", fldsym_mixin, "::", ty_mixin)
            ty = fldsym2ty[fldsym_mixin]
            @assert ty <: ty_mixin string("mixin field ", $(Ty), '.', fldsym_mixin, " is expected to be declared as subtype of ", ty_mixin, " but declared as ", fldsym_mixin, "::", ty)
        end
    end)

    Core.eval(@__MODULE__, asserter)
end

macro mixin(ex)
    @assert isexpr(ex, :struct, 3) "struct expression should be given"
    _, typedecl, body = ex.args
    @assert isexpr(typedecl, :(<:)) "mixed interface should be given as supertype"
    T = last(typedecl.args)

    Ty = Core.eval(__module__, T)
    assert_mixin(__module__, Ty, body)

    return esc(ex)
end

export
    @interface, @mixin

end

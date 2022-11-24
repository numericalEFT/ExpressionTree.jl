abstract type Operator end
struct Sum <: Operator end
struct Prod <: Operator end
# struct Diff <: Operator end
# struct Integral <: Operator end
Base.isequal(a::Operator, b::Operator) = (typeof(a) == typeof(b))
Base.:(==)(a::Operator, b::Operator) = Base.isequal(a, b)
apply(o::Operator, diags) = error("not implemented!")

Base.show(io::IO, o::Operator) = print(io, typeof(o))
Base.show(io::IO, o::Sum) = print(io, "⨁")
Base.show(io::IO, o::Prod) = print(io, "Ⓧ")
# Base.show(io::IO, o::Diff) = print(io, "d")
# Base.show(io::IO, o::Integral) = print(io, "∫")

abstract type DiagType end
struct PropagatorDig <: DiagType end
struct InteractionDiag <: DiagType end
struct SigmaDiag <: DiagType end
struct GreenDiag <: DiagType end
# TODO: more
struct OtherDiag <: DiagType end

function vstr(r, c)
    N = length(r)
    # cstr(x) = x ? "⁺" : "⁻"
    s = ""
    for i = 1:N-1
        s *= "$(r[i])$c"
    end
    s *= "$(r[end])$c"
    return s
end

function vcstr(r, creation)
    N = length(r)
    # cstr(x) = x ? "⁺" : "⁻"
    s = ""
    for i = 1:N-1
        if creation[i]
            s *= "$(r[i])⁺"
        else
            s *= "$(r[i])⁻"
        end
    end
    if creation[end]
        s *= "$(r[end])⁺"
    else
        s *= "$(r[end])⁻"
    end
    return s
end

@enum Reducibility begin
    OneFermiIrreducible
    OneBoseIrreducible
    ParticleHoleIrreducible
    ParticleParticleIrreducible
end

struct ExternalVertice
    point::Int
    current::Int
    isCreation::Bool
    isFermi::Bool
end

Base.isequal(a::ExternalVertice, b::ExternalVertice) = ((a.point == b.point) && (a.current == b.current) && (a.isCreation == b.isCreation) && (a.isFermi == b.isFermi))
Base.:(==)(a::ExternalVertice, b::ExternalVertice) = Base.isequal(a, b)

"""
    mutable struct Diagram{W}
    
    struct of a Feynman diagram. A diagram of a sum or produce of various subdiagrams.

# Members
- hash::Int           : the unique hash number to identify the diagram
- name::Symbol        : name of the diagram
- para::DiagramPara   : internal parameters of the diagram
- orders::Vector{Int} : orders of the diagram, loop order, derivative order, etc.
- internal_points::Vector{Int} : internal points in the diagram
- currents::Vector{Float64} : independent currents in the diagram
- extVertices::Vector{ExternalVertice}    : external vertices of the diagram
- isConnected::Bool   : connected or disconnected Green's function
- isAmputated::Bool   : amputated Green's function or not
- subdiagram::Vector{Diagram{W}}   : vector of sub-diagrams 
- operator::Operator  : operation, support Sum() and Prod()
- factor::W           : additional factor of the diagram
- weight::W           : weight of the diagram
"""
mutable struct Diagram{W} # Diagram
    hash::Int
    name::Symbol
    type::DiagType
    orders::Vector{Int}

    extVertices::Vector{ExternalVertice}
    isConnected::Bool
    isAmputated::Bool
    reducibility::Vector{Reducibility}
    subdiagram::Vector{Diagram{W}}

    operator::Operator
    factor::W
    weight::W

    function Diagram{W}(type, isConnected, isAmputated, extV=[], subdiagram=[];
        reducibility=[], name=:Diagram, operator::Operator=Sum(), factor=W(1), weight=W(0)) where {W}
        @assert type isa DiagType "$type is not implemented in DiagType."
        orders = zeros(Int, 16)
        g = new{W}(uid(), name, type, orders, extV, isConnected, isAmputated, reducibility, subdiagram, operator, factor, weight)
        reducibility!(g)
        return g
    end
end

function Base.show(io::IO, g::Diagram)
    strc = g.isConnected ? "connected " : "disconnected "
    stra = g.isAmputated ? "amputated " : " "
    print(io, "hash $(g.hash): " * strc * stra * "Green's function $(g.name)")
end

Base.:(==)(a::Diagram, b::Diagram) = Base.isequal(a, b)
function Base.isequal(a::Diagram, b::Diagram)
    typeof(a) != typeof(b) && return false
    for field in fieldnames(typeof(a))
        if field == :weight
            (getproperty(a, :weight) ≈ getproperty(b, :weight)) == false && return false
        end
        getproperty(a, field) != getproperty(b, field) && return false
    end
    return true
end
# isbare(diag::Diagram) = isempty(diag.subdiagram)

function reducibility(g::Diagram{W}) where {W}
    return ()
end

function reducibility!(g::Diagram{W}) where {W}
    # @assert g.reducibility ⊆ reducibility(g) "wrong reducibility in g (hash: $g.hash)."
    g.reducibility = union(reducibility(g), g.reducibility)
end

function Base.:*(g1::Diagram{W}, g2::Diagram{W}) where {W}
    type = OtherDiag()
    ext1_ind = [v.point for v in g1.extVertices]
    ext2_ind = [v.point for v in g2.extVertices]
    common = intersect(ext1_ind, ext2_ind)
    total = union(g1.extVertices, g2.extVertices)
    ext = [v for v in total if v.point ∉ common]
    #TODO: add external vertices creation/annihilation check
    return Diagram{W}(type, g1.isConnected && g2.isConnected, g1.isAmputated || g2.isAmputated, ext, [g1, g2], operator=Prod())
end

function Base.:*(g1::Diagram{W}, c2::Number) where {W}
    return Diagram{W}(g1.type, g1.isConnected, g1.isAmputated, g1.extVertices, [g1,], operator=Prod(), factor=c2)
end

function Base.:*(c1::Number, g2::Diagram{W}) where {W}
    return Diagram{W}(g2.type, g2.isConnected, g2.isAmputated, g2.extVertices, [g2,], operator=Prod(), factor=c1)
end

function Base.:+(g1::Diagram{W}, g2::Diagram{W}) where {W}
    @assert g1.type == g2.type "g1 and g2 are not of the same type."
    @assert g1.isAmputated == g2.isAmputated "g1 and g2 are not of the same amputated status."
    # TODO: more check
    type = g1.type
    @assert Set(g1.extVertices) == Set(g2.extVertices)
    #TODO: add external vertices creation/annihilation check
    return Diagram{W}(type, g1.isConnected && g2.isConnected, g1.isAmputated, g1.extVertices, [g1, g2], operator=Sum())
end

function Base.:-(g1::Diagram{W}, g2::Diagram{W}) where {W}
    return g1 + (-1) * g2
end
# g = Sigma(...)
# w = W(...)
# ver4 = Vertex4(...)

# graph = g*w+ver4*0.5

function 𝐺ᶠ(point_in::Int, point_out::Int, current::Int=0; kwargs...)
    return Green2(point_in, point_out, current; isFermi=true, kwargs...)
end

function 𝐺ᵇ(point_in::Int, point_out::Int, current::Int=0; kwargs...)
    return Green2(point_in, point_out, current; isFermi=false, kwargs...)
end

function Green2(point_in::Int, point_out::Int, current::Int=0;
    isFermi=true,
    dtype=Float64, factor=zero(dtype), weight=zero(dtype), name=:G2, subdiagram=[], operator=Sum())
    ext_in = ExternalVertice(point_in, current, true, isFermi)
    ext_out = ExternalVertice(point_out, current, false, isFermi)
    if isnothing(subdiagram)
        diagtype = PropagatorDig()
    else
        diagtype = GreenDiag()
    end
    return Diagram{dtype}(diagtype, true, false, [ext_in, ext_out], subdiagram,
        name=name, operator=operator, factor=factor, weight=weight)
end

const 𝑊 = Interaction

function Interaction(point_in::Int, point_out::Int, current::Int=0;
    dtype=Float64, factor=zero(dtype), weight=zero(dtype), name=:W)
    ext_in = ExternalVertice(point_in, current, true, false)
    ext_out = ExternalVertice(point_out, current, false, false)
    diagtype = InteractionDiag()
    return Diagram{dtype}(diagtype, true, false, [ext_in, ext_out], [],
        name=name, factor=factor, weight=weight)
end

# function Diagram{W}(::Type{Vacuum}; isConnected=false, isAmputated=true, extV=[],
#     subdiagram=[], reducibility=[], name=:VacuumDiagram, operator::Operator=Sum(), factor=W(1), weight=W(0)) where {W}
#     @assert para.type == Vacuum "types from input and para are inconsistent."
#     @assert length(extV) == 0 "input parameters do not support Vacuum diagram."
#     return Diagram{W}(Vaccum, isConnected, isAmputated, [], subdiagram, reducibility=reducibility,
#         name=name, operator=operator, factor=factor, weight=weight)
# end

# function Diagram{W}(::Type{Tadpole}, para::DiagramPara; isConnected=true, isAmputated=false, extV=[],
#     subdiagram=[], reducibility=[], name=:TadpoleDiagram, operator::Operator=Sum(), factor=W(1), weight=W(0)) where {W}
#     @assert para.type == Tadpole "types from input and para are inconsistent."
#     @assert length(extV) == 1 "input parameters do not support Tadpole diagram."
#     return Diagram{W}(para, isConnected, isAmputated, extV, subdiagram, reducibility=reducibility,
#         name=name, operator=operator, factor=factor, weight=weight)
# end

# function Diagram{W}(::Type{FermiPropagator}, para::DiagramPara; isConnected=true, isAmputated=false, extV=[],
#     subdiagram=[], reducibility=[OneFermiIrreducible,], name=:FermiPropagator, operator::Operator=Sum(), factor=W(1), weight=W(0)) where {W}
#     @assert para.type == FermiPropagator "types from input and para are inconsistent."
#     @assert length(extV) == 2 && extV[1].isFermi && extV[2].isFermi &&
#             ((extV[1].isCreation && !extV[2].isCreation) || (!extV[1].isCreation && extV[2].isCreation)) "input parameters do not support FermiPropagator."
#     return Diagram{W}(para, isConnected, isAmputated, extV, subdiagram, reducibility=reducibility,
#         name=name, operator=operator, factor=factor, weight=weight)
# end

# function Diagram{W}(::Type{BosePropagator}, para::DiagramPara; isConnected=true, isAmputated=false, extV=[],
#     subdiagram=[], reducibility=[OneBoseIrreducible,], name=:BosePropagator, operator::Operator=Sum(), factor=W(1), weight=W(0)) where {W}
#     @assert para.type == BosePropagator "types from input and para are inconsistent."
#     @assert length(extV) == 2 && !extV[1].isFermi && !extV[2].isFermi &&
#             ((extV[1].isCreation && !extV[2].isCreation) || (!extV[1].isCreation && extV[2].isCreation)) "input parameters do not support BosePropagator."
#     return Diagram{W}(para, isConnected, isAmputated, extV, subdiagram, reducibility=reducibility,
#         name=name, operator=operator, factor=factor, weight=weight)
# end

# function Diagram{W}(::Type{FermiSelfEnergy}, para::DiagramPara; isConnected=true, isAmputated=true, extV=[],
#     subdiagram=[], reducibility=[OneFermiIrreducible,], name=:FermiSelfEnergy, operator::Operator=Sum(), factor=W(1), weight=W(0)) where {W}
#     @assert para.type == FermiSelfEnergy "types from input and para are inconsistent."
#     @assert length(extV) == 2 && extV[1].isFermi && extV[2].isFermi "input parameters do not support FermiSelfEnergy."
#     return Diagram{W}(para, isConnected, isAmputated, extV, subdiagram, reducibility=reducibility,
#         name=name, operator=operator, factor=factor, weight=weight)
# end

# function Diagram{W}(::Type{BoseSelfEnergy}, para::DiagramPara; isConnected=true, isAmputated=true, extV=[],
#     subdiagram=[], reducibility=[OneFermiIrreducible,], name=:BoseSelfEnergy, operator::Operator=Sum(), factor=W(1), weight=W(0)) where {W}
#     @assert para.type == BoseSelfEnergy "types from input and para are inconsistent."
#     @assert length(extV) == 2 && !extV[1].isFermi && !extV[2].isFermi "input parameters do not support BoseSelfEnergy."
#     return Diagram{W}(para, isConnected, isAmputated, extV, subdiagram, reducibility=reducibility,
#         name=name, operator=operator, factor=factor, weight=weight)
# end

# function Diagram{W}(::Type{VertexDiag}, para::DiagramPara; Nf=2, Nb=1, isConnected=true, isAmputated=true, extV=[],
#     subdiagram=[], reducibility=[OneFermiIrreducible, OneBoseirreducible], name=:VertexDiagram, operator::Operator=Sum(), factor=W(1), weight=W(0)) where {W}
#     @assert para.type == VertexDiag "types from input and para are inconsistent."
#     @assert length(extV) > 2 && length(extV) == Nf + Nb "input parameters do not support Vertex diagram."
#     return Diagram{W}(para, isConnected, isAmputated, extV, subdiagram, reducibility=reducibility,
#         name=name, operator=operator, factor=factor, weight=weight)
# end

# function Diagram{W}(::Type{GncDiag}, para::DiagramPara; N=4, isConnected=true, isAmputated=false, extV=[],
#     subdiagram=[], reducibility=[], name=:ConnectedNDiagram, operator::Operator=Sum(), factor=W(1), weight=W(0)) where {W}
#     @assert para.type == GncDiag "types from input and para are inconsistent."
#     @assert length(extV) > 2 && length(extV) == N "input parameters do not support Connected N-point diagram."
#     return Diagram{W}(para, isConnected, isAmputated, extV, subdiagram, reducibility=reducibility,
#         name=name, operator=operator, factor=factor, weight=weight)
# end

# function Diagram{W}(::Type{GndDiag}, para::DiagramPara; N=4, isConnected=false, isAmputated=false, extV=[],
#     subdiagram=[], reducibility=[], name=:DisconnectedNDiagram, operator::Operator=Sum(), factor=W(1), weight=W(0)) where {W}
#     @assert para.type == GndDiag "types from input and para are inconsistent."
#     @assert length(extV) > 2 && length(extV) == N "input parameters do not support Disconnected N-point diagram."
#     return Diagram{W}(para, isConnected, isAmputated, extV, subdiagram, reducibility=reducibility,
#         name=name, operator=operator, factor=factor, weight=weight)
# end

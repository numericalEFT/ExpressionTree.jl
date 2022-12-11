abstract type AbstractOperator end
struct Sum <: AbstractOperator end
struct Prod <: AbstractOperator end
Base.isequal(a::AbstractOperator, b::AbstractOperator) = (typeof(a) == typeof(b))
Base.:(==)(a::AbstractOperator, b::AbstractOperator) = Base.isequal(a, b)
apply(o::AbstractOperator, diags) = error("not implemented!")

Base.show(io::IO, o::AbstractOperator) = print(io, typeof(o))
Base.show(io::IO, ::Type{Sum}) = print(io, "⨁")
Base.show(io::IO, ::Type{Prod}) = print(io, "Ⓧ")

"""
    mutable struct Graph{F,W}
    
    Computational Graph representation of a collection of Feynman diagrams. All Feynman diagrams should share the same set of external and internal vertices.

# Members:
- `id::Int`  the unique hash id to identify the diagram
- `name::Symbol`  name of the diagram
- `type::Symbol`  type of the diagram, support :propagator, :interaction, :sigma, :green, :generic
- `orders::Vector{Int}`  orders of the diagram, e.g. loop order, derivative order, etc.
- `external::Vector{Int}`  index of external vertices (as QuantumOperators)
- `vertices::Vector{OperatorProduct}`  vertices of the diagram. Each index is composited by the product of quantum operators.
- `topology::Vector{Vector{Int}}` topology of the diagram. Each Vector{Int} stores vertices' index connected with each other (as a propagator). 
- `subgraphs::Vector{Graph{F,W}}`  vector of sub-diagrams 
- `subgraph_factors::Vector{F}`  scalar multiplicative factors associated with each subdiagram
- `operator::DataType`  node operation, support Sum and Prod
- `factor::F`  total scalar multiplicative factor for the diagram
- `weight::W`  weight of the diagram

# Example:
```julia-repl
julia> g = Graph([𝑓⁺(1)𝑓⁻(2), 𝑓⁺(3)𝑓⁻(4)], external=[1, 2], subgraphs=[Graph([𝑓⁺(1)𝑓⁻(4)], []), Graph([𝑓⁻(2)𝑓⁺(3)], [])])
3:f⁺(1)f⁻(2)|f⁺(3)f⁻(4)=0.0=⨁ (1,2)

julia> g.subgraphs
2-element Vector{Graph{Float64, Float64}}:
 1:f⁺(1)f⁻(4)=0.0
 2:f⁻(2)f⁺(3)=0.0
```
"""
mutable struct Graph{F,W} # Graph
    id::Int
    name::String # "" by default
    type::Symbol # :propagator, :interaction, :sigma, :green, :generic
    orders::Vector{Int}

    external::Vector{Int} # index of external vertices
    vertices::Vector{OperatorProduct} # vertices of the diagram
    topology::Vector{Vector{Int}}

    subgraphs::Vector{Graph{F,W}}
    subgraph_factors::Vector{F}

    operator::DataType
    factor::F
    weight::W

    """
        function Graph(vertices::Vector{OperatorProduct}; external=[], subgraphs=[],
            name="", type=:generic, operator::AbstractOperator=Sum(), orders=zeros(Int, 16),
            ftype=_dtype.factor, wtype=_dtype.weight, factor=one(ftype), weight=zero(wtype))
        
        Create a Graph struct from vertices and external indices.

    # Arguments:
    - `vertices::Vector{OperatorProduct}`  vertices of the diagram
    - `external`  index of external vertices in terms of QuantumOperators, empty by default
    - `topology` topology of the diagram
    - `subgraphs`  vector of sub-diagrams 
    - `subgraph_factors::Vector{F}`  scalar multiplicative factors associated with each subdiagram
    - `name`  name of the diagram
    - `type`  type of the diagram
    - `operator::DataType`  node operation, Sum, Prod, etc.
    - `orders`  orders of the diagram
    - `ftype`  typeof(factor)
    - `wtype`  typeof(weight)
    - `factor::F`  overall scalar multiplicative factor for this diagram (e.g., permutation sign)
    - `weight`  weight of the diagram
    """
    function Graph(vertices::AbstractVector; external=[], subgraphs=[], subgraph_factors=one.(eachindex(subgraphs)),
        topology=[], name="", type=:generic, operator::AbstractOperator=Sum(), orders=zeros(Int, 16),
        ftype=_dtype.factor, wtype=_dtype.weight, factor=one(ftype), weight=zero(wtype)
    )
        vertices = [OperatorProduct(v) for v in vertices]
        return new{ftype,wtype}(uid(), name, type, orders, external, vertices, topology,
            subgraphs, subgraph_factors, typeof(operator), factor, weight)
    end
end

function Base.isequal(a::Graph, b::Graph)
    typeof(a) != typeof(b) && return false
    for field in fieldnames(typeof(a))
        if field == :weight
            (getproperty(a, :weight) ≈ getproperty(b, :weight)) == false && return false
        else
            getproperty(a, field) != getproperty(b, field) && return false
        end
    end
    return true
end
Base.:(==)(a::Graph, b::Graph) = Base.isequal(a, b)
# isbare(diag::Graph) = isempty(diag.subgraphs)

"""
    function isequiv(a::Graph, b::Graph, args...)

    Determine whether `a` is equivalent to `b` without considering fields in `args`.
"""
function isequiv(a::Graph, b::Graph, args...)
    typeof(a) != typeof(b) && return false
    for field in fieldnames(typeof(a))
        field in [args...] && continue
        if field == :weight
            (getproperty(a, :weight) ≈ getproperty(b, :weight)) == false && return false
        elseif field == :subgraphs
            !all(isequiv.(getproperty(a, field), getproperty(b, field), args...)) && return false
        else
            getproperty(a, field) != getproperty(b, field) && return false
        end
    end
    return true
end

"""
    function is_external(g::Graph, i::Int) 

    Check if `i::Int` in the external indices of Graph `g`.
"""
is_external(g::Graph, i::Int) = i in g.external

"""
    function is_internal(g::Graph, i::Int) 

    Check if `i::Int` in the internal indices of Graph `g`.
"""
is_internal(g::Graph, i::Int) = (i in g.external) == false

"""
    function external(g::Graph)

    Return all external vertices (::Vector{QuantumOperators}) of Graph `g`.
"""
external(g::Graph) = OperatorProduct(g.vertices)[g.external]

"""
    function vertices(g::Graph)

    Return all vertices (::Vector{OperatorProduct}) of Graph `g`.
"""
vertices(g::Graph) = g.vertices

#TODO: add function return reducibility of Graph. 
function reducibility(g::Graph)
    return (OneFermiIrreducible,)
end

#TODO: add function for connected diagram check. 
function connectivity(g::Graph)
    isempty(g.subgraphs) && return true
end

function Base.:*(g1::Graph{F,W}, c2::C) where {F,W,C}
    g = Graph(g1.vertices; external=g1.external, type=g1.type, topology=g1.topology,
        subgraphs=[g1,], subgraph_factors=[F(c2),], operator=Prod(), ftype=F, wtype=W)
    # Merge multiplicative chains
    if g1.operator == Prod && length(g1.subgraph_factors) == 1
        g.subgraph_factors[1] *= g1.subgraph_factors[1]
        g.subgraphs = g1.subgraphs
    end
    return g
end

function Base.:*(c1::C, g2::Graph{F,W}) where {F,W,C}
    g = Graph(g2.vertices; external=g2.external, type=g2.type, topology=g2.topology,
        subgraphs=[g2,], subgraph_factors=[F(c1),], operator=Prod(), ftype=F, wtype=W)
    # Merge multiplicative chains
    if g2.operator == Prod && length(g2.subgraph_factors) == 1
        g.subgraph_factors[1] *= g2.subgraph_factors[1]
        g.subgraphs = g2.subgraphs
    end
    return g
end

"""Returns a graph representing the linear combination `c1*g1 + c2*g2`."""
function linear_combination(g1::Graph{F,W}, g2::Graph{F,W}, c1::C, c2::C) where {F,W,C}
    # TODO: more check
    @assert g1.type == g2.type "g1 and g2 are not of the same type."
    @assert g1.orders == g2.orders "g1 and g2 have different orders."
    @assert Set(vertices(g1)) == Set(vertices(g2)) "g1 and g2 have different vertices."
    @assert Set(external(g1)) == Set(external(g2)) "g1 and g2 have different external vertices."
    return Graph(g1.vertices; external=g1.external, type=g1.type, subgraphs=[g1, g2],
        subgraph_factors=[F(c1), F(c2)], operator=Sum(), ftype=F, wtype=W)
end

"""
Given a vector `graphs` of graphs each with the same type and external/internal
vertices and an equally-sized vector `constants` of constants, returns a new
graph representing the linear combination ⟨`graphs`, `constants`⟩.
"""
function linear_combination(graphs::Vector{Graph{F,W}}, constants::Vector{C}) where {F,W,C}
    # TODO: more check
    @assert allequal(getproperty.(graphs, :type)) "Graphs are not all of the same type."
    @assert allequal(getproperty.(graphs, :orders)) "Graphs do not all have the same order."
    @assert allequal(Set.(vertices.(graphs))) "Graphs do not share the same set of vertices."
    @assert allequal(Set.(external.(graphs))) "Graphs do not share the same set of external vertices."
    g1 = graphs[1]
    return Graph(g1.vertices; external=g1.external, type=g1.type, subgraphs=graphs,
        subgraph_factors=constants, operator=Sum(), ftype=F, wtype=W)
end

function Base.:+(g1::Graph{F,W}, g2::Graph{F,W}) where {F,W}
    return linear_combination(g1, g2, F(1), F(1))
end

function Base.:-(g1::Graph{F,W}, g2::Graph{F,W}) where {F,W}
    return linear_combination(g1, g2, F(1), F(-1))
end

# function Base.:+(g1::Graph{F,W}, g2::Graph{F,W}) where {F,W}
#     return linear_combination([g1, g2], [F(1), F(1)])
# end

# function Base.:-(g1::Graph{F,W}, g2::Graph{F,W}) where {F,W}
#     return linear_combination([g1, g2], [F(1), F(-1)])
# end

"""
    function feynman_diagram(vertices::Vector{OperatorProduct}, topology::Vector{Vector{Int}};
        external=[], factor=one(_dtype.factor), weight=zero(_dtype.weight), name="", type=:generic)
    
    Create a Graph representing feynman diagram from all vertices and topology (connections between vertices).

# Arguments:
- `vertices::Vector{OperatorProduct}`  vertices of the diagram
- `topology::Vector{Vector{Int}}` topology of the diagram. Each Vector{Int} stores vertices' index connected with each other (as a propagator). 
- `external`  index of external vertices
- `factor::F`  overall scalar multiplicative factor for this diagram (e.g., permutation sign)
- `weight`  weight of the diagram
- `name`  name of the diagram
- `type`  type of the diagram

# Example:
```julia-repl
julia> g = feynman_diagram([𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6)], [[5, 1], [2, 4], [3, 6]])
1: generic graph from f⁺(1)f⁻(2)ϕ(3)|f⁺(4)f⁻(5)ϕ(6)

julia> g.subgraphs
3-element Vector{Graph{Float64, Float64}}:
 2: propagator graph from f⁻(5)f⁺(1)
 3: propagator graph from f⁻(2)f⁺(4)
 4: propagator graph from ϕ(3)ϕ(6)
```
"""
function feynman_diagram(vertices::Vector{OperatorProduct}, topology::Vector{Vector{Int}};
    external::Union{Nothing,AbstractVector}=nothing, factor=one(_dtype.factor), weight=zero(_dtype.weight), name="", type=:generic)

    operators = [o for v in vertices for o in v.operators]
    contraction = collect(Iterators.flatten(topology))
    if isnothing(external)
        external = [i for i in eachindex(operators) if i ∉ contraction]
    end
    @assert length(unique(contraction)) == length(contraction) # no repeated index
    @assert length(unique(external)) == length(external) # no repeated index
    @assert Set(union(external, contraction)) == Set(eachindex(operators)) # external + permutation must exhaust all operators

    permutation = union(contraction, external)
    _external = intersect(external, contraction)

    fermionic_operators = isfermionic.(operators)
    filter!(p -> fermionic_operators[p], permutation)
    sign = isempty(permutation) ? 1 : parity(sortperm(permutation))

    filter!(p -> fermionic_operators[p], _external)
    ext_sign = isempty(_external) ? 1 : parity(sortperm(_external))
    # println(_external, ", ", ext_sign)

    subgraphs = [propagator(reduce(*, operators[connection])) for connection in topology]
    g = Graph(vertices; external=external, subgraphs=subgraphs, topology=topology, name=name,
        type=type, operator=Prod(), factor=factor * sign * ext_sign, weight=weight)
    return g
end

"""
    function propagator(ops::OperatorProduct;
        name="", diagtype=:propagator, factor=one(_dtype.factor), weight=zero(_dtype.weight), operator=Sum())

    Create a propagator-type Graph from given OperatorProduct `ops`.
"""
function propagator(ops::OperatorProduct;
    name="", diagtype=:propagator, factor=one(_dtype.factor), weight=zero(_dtype.weight), operator=Sum())
    return Graph([ops,]; external=collect(eachindex(ops)), type=diagtype, name=name, operator=operator, factor=factor, weight=weight)
end

"""
    function standardize_order!(g::Graph)

    Standardize the order of all leaves (propagators) of Graph by correlator ordering.

# Example: 
```julia-repl
julia> g = propagator(𝑓⁺(1)𝑏⁺(2)𝜙(3)𝑓⁻(1)𝑏⁻(2))
1: propagator graph from f⁺(1)b⁺(2)ϕ(3)f⁻(1)b⁻(2)

julia> standardize_order!(g)

julia> g, g.factor
(1: propagator graph from f⁻(1)b⁻(2)ϕ(3)b⁺(2)f⁺(1), -1.0)
```
"""
function standardize_order!(g::Graph)
    for node in PreOrderDFS(g)
        if isempty(node.subgraphs)
            sign, perm = correlator_order(OperatorProduct(external(node)))
            node.external = node.external[perm]
            node.factor *= sign
        else
            sign, perm = normal_order(OperatorProduct(external(node)))
            node.external = node.external[perm]
            node.factor *= sign
        end
    end
end

prune_unary(g::Graph)=((length(g.subgraph)==1 && g.subgraph_factors[1]==1 && g.factor == 1) ? g.subgraph[1] : g)

function inplace_prod(g1::Graph{F,W}) where {F,W}
    if (length(g1.subgraphs)==1 && (g1.operator == Prod))
        g0 = g1.subgraphs[1]
        g = Graph(g0.vertices; external=g0.external, type=g0.type, topology=g0.topology,
        subgraphs=g0.subgraphs, factor = g1.subgraph_factors[1]*g1.factor*g0.factor, operator= g0.operator(), ftype=F, wtype=W)
        return g
    else
        return g1
    end
end

# function merge_prefactors(g0::Graph{F,W}) where {F,W}
#     if (g1.operator==Sum && length(g1.subgraphs)==2 && isequiv(g1.subgraphs[1], g1.subgraphs[2], :factor, :id, :subgraph_factors))
#         g1 = g0.subgraph[1]
#         g2 = g0.subgraph[2]
#         g_subg = Graph(g1.vertices; external=g1.external, type=g1.type, topology=g1.topology,
#         subgraphs=g1.subgraphs, operator=g1.operator(), ftype=F, wtype=W)
#         g = Graph(g1.vertices; external=g1.external, type=g1.type, topology=g1.topology,
#         subgraphs=[g_subg,], operator=Prod(), ftype=F, wtype=W)
#         g.subgraph_factors[1] = (g1.subgraph_factors[1]*g1.factor+g1.subgraph_factors[2]*g1.subgraphs[2].factor) * g0.factor
#         return g
#     else
#         return g1
#     end
# end

# 

#####################  interface to AbstractTrees ########################### 
function AbstractTrees.children(diag::Graph)
    return diag.subgraphs
end

## Things that make printing prettier
AbstractTrees.printnode(io::IO, diag::Graph) = print(io, "\u001b[32m$(diag.id)\u001b[0m : $diag")
AbstractTrees.nodetype(::Graph{F,W}) where {F,W} = Graph{F,W}

## Optional enhancements
# These next two definitions allow inference of the item type in iteration.
# (They are not sufficient to solve all internal inference issues, however.)
Base.IteratorEltype(::Type{<:TreeIterator{Graph{F,W}}}) where {F,W} = Base.HasEltype()
Base.eltype(::Type{<:TreeIterator{Graph{F,W}}}) where {F,W} = Graph{F,W}

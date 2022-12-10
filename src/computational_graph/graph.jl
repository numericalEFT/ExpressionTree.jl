abstract type AbstractOperator end
struct Sum <: AbstractOperator end
struct Prod <: AbstractOperator end
Base.isequal(a::AbstractOperator, b::AbstractOperator) = (typeof(a) == typeof(b))
Base.:(==)(a::AbstractOperator, b::AbstractOperator) = Base.isequal(a, b)
apply(o::AbstractOperator, diags) = error("not implemented!")

Base.show(io::IO, o::AbstractOperator) = print(io, typeof(o))
Base.show(io::IO, ::Type{Sum}) = print(io, "⨁")
Base.show(io::IO, ::Type{Prod}) = print(io, "Ⓧ")

# """Type alias for a directed graph edge e = (a₁⁺, a₂⁻) from e[1] to e[2]."""
# const EdgeType = Tuple{QuantumOperator,QuantumOperator}

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
- `subgraph_factors::Vector{F}`  scalar multiplicative factors for each subdiagram
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
    - `subgraph_factors::Vector{F}`  scalar multiplicative factors for each subdiagram
    - `name`  name of the diagram
    - `type`  type of the diagram
    - `operator::DataType`  node operation, Sum, Prod, etc.
    - `orders`  orders of the diagram
    - `ftype`  typeof(factor)
    - `wtype`  typeof(weight)
    - `factor::F`  total scalar multiplicative factor for the diagram
    - `weight`  weight of the diagram
    """
    function Graph(vertices::AbstractVector; external=[], subgraphs=[], subgraph_factors=getproperty.(subgraphs, :factor),
        topology=[], name="", type=:generic, operator::AbstractOperator=Sum(), orders=zeros(Int, 16),
        ftype=_dtype.factor, wtype=_dtype.weight, factor=one(ftype), weight=zero(wtype)
    )
        vertices = [OperatorProduct(v) for v in vertices]
        return new{ftype,wtype}(uid(), name, type, orders, external, vertices, topology, subgraphs, subgraph_factors, typeof(operator), factor, weight)
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

# """
#     function internal_vertices(g::Graph)

#     Return all internal vertices (::Vector{OperatorProduct}) of Graph `g`.
# """
# internal_vertices(g::Graph) = g.vertices[setdiff(eachindex(g.vertices), g.external)]

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
    return Graph(g1.vertices; external=g1.external, type=g1.type, topology=g1.topology,
        subgraphs=[g1,], operator=Prod(), ftype=F, wtype=W, factor=F(c2) * g1.factor)
end

function Base.:*(c1::C, g2::Graph{F,W}) where {F,W,C}
    return Graph(g2.vertices; external=g2.external, type=g2.type, topology=g2.topology,
        subgraphs=[g2,], operator=Prod(), ftype=F, wtype=W, factor=F(c1) * g2.factor)
end

function Base.:+(g1::Graph{F,W}, g2::Graph{F,W}) where {F,W}
    @assert g1.type == g2.type "g1 and g2 are not of the same type."
    # TODO: more check
    @assert Set(vertices(g1)) == Set(vertices(g2)) "g1 and g2 have different vertices."
    @assert Set(external(g1)) == Set(external(g2)) "g1 and g2 have different external vertices."
    @assert g1.orders == g2.orders "g1 and g2 have different orders."

    return Graph(g1.vertices; external=g1.external, type=g1.type, subgraphs=[g1, g2], operator=Sum(), ftype=F, wtype=W)
end

function Base.:-(g1::Graph{F,W}, g2::Graph{F,W}) where {F,W}
    return g1 + (-F(1)) * g2
end

# """
#     function feynman_diagram(vertices::Vector{OperatorProduct}, contractions::Vector{Int};
#         external=[], factor=one(_dtype.factor), weight=zero(_dtype.weight), name="", type=:generic)

#     Create a Graph representing feynman diagram from all vertices and Wick contractions.

# # Arguments:
# - `vertices::Vector{OperatorProduct}`  vertices of the diagram
# - `contractions::Vector{Int}`  contraction-index vector respresnting Wick contractions
# - `external`  index of external vertices
# - `factor`  scalar multiplicative factor for the diagram
# - `weight`  weight of the diagram
# - `name`  name of the diagram
# - `type`  type of the diagram

# # Example:
# ```julia-repl
# julia> g = feynman_diagram([𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6)], [1, 2, 3, 2, 1, 3])
# 1: generic graph from f⁺(1)f⁻(2)ϕ(3)|f⁺(4)f⁻(5)ϕ(6)

# julia> g.subgraphs
# 3-element Vector{Graph{Float64, Float64}}:
#  2: propagtor graph from f⁺(1)f⁻(5)
#  3: propagtor graph from f⁻(2)f⁺(4)
#  4: propagtor graph from ϕ(3)ϕ(6)
# ```
# """
# function feynman_diagram(vertices::Vector{OperatorProduct}, contractions::Vector{Int};
#     external=[], factor=one(_dtype.factor), weight=zero(_dtype.weight), name="", type=:generic)

#     contraction_sign, topology, edges = contractions_to_edges(vertices, contractions)
#     g = Graph(vertices; external=external, topology=topology, name=name, type=type, operator=Prod(),
#         factor=factor * contraction_sign, weight=weight)
#     for edge in edges
#         push!(g.subgraphs, propagator(reduce(*, edge)))
#     end
#     return g
# end
# function feynman_diagram(graphs::Vector{Graph{F,W}}, contractions::Vector{Int};
#     external=[], factor=one(_dtype.factor), weight=zero(_dtype.weight), name="", type=:generic) where {F,W}

#     vertices = [v for g in graphs for v in external_vertices(g)]
#     return feynman_diagram(vertices, contractions; external=external, factor=factor, weight=weight, name=name, type=type)
# end

"""
    function feynman_diagram(vertices::Vector{OperatorProduct}, topology::Vector{Vector{Int}};
        external=[], factor=one(_dtype.factor), weight=zero(_dtype.weight), name="", type=:generic)
    
    Create a Graph representing feynman diagram from all vertices and topology (connections between vertices).

# Arguments:
- `vertices::Vector{OperatorProduct}`  vertices of the diagram
- `topology::Vector{Vector{Int}}` topology of the diagram. Each Vector{Int} stores vertices' index connected with each other (as a propagator). 
- `external`  index of external vertices
- `factor`  scalar multiplicative factor for the diagram
- `weight`  weight of the diagram
- `name`  name of the diagram
- `type`  type of the diagram

# Example:
```julia-repl
julia> g = feynman_diagram([𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6)], [[5, 1], [2, 4], [3, 6]])
1: generic graph from f⁺(1)f⁻(2)ϕ(3)|f⁺(4)f⁻(5)ϕ(6)

julia> g.subgraphs
3-element Vector{Graph{Float64, Float64}}:
 2: propagtor graph from f⁻(5)f⁺(1)
 3: propagtor graph from f⁻(2)f⁺(4)
 4: propagtor graph from ϕ(3)ϕ(6)
```
"""
function feynman_diagram(vertices::Vector{OperatorProduct}, topology::Vector{Vector{Int}};
    external::Union{Nothing,AbstractVector}=nothing, factor=one(_dtype.factor), weight=zero(_dtype.weight), name="", type=:generic)

    operators = [o for v in vertices for o in v.operators]
    permutation = collect(Iterators.flatten(topology))
    if isnothing(external)
        external = [i for i in eachindex(operators) if i ∉ permutation]
    end
    @assert length(unique(permutation)) == length(permutation) # no repeated index
    @assert length(unique(external)) == length(external) # no repeated index
    @assert Set(union(external, permutation)) == Set(eachindex(operators)) # external + permutation must exhaust all operators

    fermionic_operators = isfermionic.(operators)
    filter!(p -> fermionic_operators[p], permutation)
    sign = isempty(permutation) ? 1 : parity(sortperm(permutation))

    _external = filter(p -> fermionic_operators[p], external)
    ext_sign = isempty(_external) ? 1 : parity(sortperm(_external))
    # println(_external, ", ", ext_sign)

    g = Graph(vertices; external=external, topology=topology, name=name, type=type, operator=Prod(),
        factor=factor * sign * ext_sign, weight=weight)
    for connection in topology
        push!(g.subgraphs, propagator(reduce(*, operators[connection])))
    end
    return g
end
# function feynman_diagram(graphs::Vector{Graph{F,W}}, topology::Vector{Vector{Int}};
#     external=[], factor=one(_dtype.factor), weight=zero(_dtype.weight), name="", type=:generic) where {F,W}

#     vertices = reduce(*, [v for g in graphs for v in external_vertices(g)])
#     return feynman_diagram(vertices, topology; external=external, factor=factor, weight=weight, name=name, type=type)
# end

# """
#     function contractions_to_edges(vertices::Vector{OperatorProduct}, contractions::Vector{Int})

#     Converts a list of Wick contractions associated with a list of vertices
#     to a list of edges e = (i, j) directed from `operators[i]` to `operators[j]`, where
#     `operators` is a flattened list of operators associated with the specified `vertices`.

# # Example: 
# ```julia-repl
# julia> vertices = [𝑏⁺(1)𝑓⁺(2)𝜙(3), 𝑓⁻(4)𝑓⁻(5), 𝑏⁻(6)𝑓⁺(7)𝜙(8)];

# julia> edges, sign = contractions_to_edges(vertices, [1, 2, 3, 2, 4, 1, 4, 3])
# (Tuple{QuantumOperator, QuantumOperator}[(b⁺(1), b⁻(6)), (f⁺(2), f⁻(4)), (ϕ(3), ϕ(8)), (f⁻(5), f⁺(7))], 1)
# ```
# - flattened fermionic edges: [2, 4, 5, 7]
# - sign = parity([1, 2, 3, 4]) = 1
# """
# function contractions_to_edges(vertices::Vector{OperatorProduct}, contractions::Vector{Int})
#     #TODO: only works for weak-coupling expansion with Wick's theorem for now.
#     # Obtain the flattened list of non-composite operators
#     operators = [o for v in vertices for o in v.operators]
#     # Filter some illegal contractions
#     is_invalid =
#         isodd(length(contractions)) ||
#         # isodd(length(unique(contractions))) ||
#         length(operators) != length(contractions)
#     if is_invalid
#         throw(
#             ArgumentError(
#                 "Input $contractions does not specify a legal set of Wick contractions",
#             ),
#         )
#     end
#     # Loop over operators and pair
#     next_pairing = 1
#     edges = Vector{EdgeType}()
#     topology = Vector{Int}[]
#     permutation = Int[]

#     for (i, wick_i) in enumerate(contractions)
#         if i < next_pairing
#             continue  # Operator already paired
#         end
#         for (js, wick_j) in enumerate(contractions[(i+1):end])
#             j = i + js  # Iterating for (j > i)
#             if j < next_pairing
#                 continue  # Operator already paired
#             end
#             if wick_i == wick_j
#                 @debug "Found Wick contraction #$wick_i, adding edge between operators $i and $j"
#                 @assert operators[j]'.operator == operators[i].operator
#                 isfermionic(operators[j]) && append!(permutation, [i, j])
#                 push!(edges, (operators[i], operators[j]))
#                 push!(topology, [i, j])
#                 # Move on to next pair
#                 next_pairing += 1
#                 break
#             end
#         end
#     end
#     # Deduce the parity of the contraction
#     # Get the permutation parity for the flattened list of fermionic edges, e.g.,
#     # permutation = [1, 5, 4, 8, 7, 6] => P = (1 3 2 6 5 4) => sign = +1
#     sign = isempty(permutation) ? 1 : parity(sortperm(permutation))

#     return sign, topology, edges
# end

"""
    function propagator(ops::OperatorProduct;
        name="", diagtype=:propagtor, factor=one(_dtype.factor), weight=zero(_dtype.weight), operator=Sum())

    Create a propagator-type Graph from given OperatorProduct `ops`.
"""
function propagator(ops::OperatorProduct;
    name="", diagtype=:propagtor, factor=one(_dtype.factor), weight=zero(_dtype.weight), operator=Sum())
    return Graph([ops,]; external=collect(eachindex(ops)), type=diagtype, name=name, operator=operator, factor=factor, weight=weight)
end

"""
    function standardize_order!(g::Graph)

    Standardize the order of all leaves (propagators) of Graph by correlator ordering.

# Example: 
```julia-repl
julia> g = propagator(𝑓⁺(1)𝑏⁺(2)𝜙(3)𝑓⁻(1)𝑏⁻(2))
1: propagtor graph from f⁺(1)b⁺(2)ϕ(3)f⁻(1)b⁻(2)

julia> standardize_order!(g)

julia> g, g.factor
(1: propagtor graph from f⁻(1)b⁻(2)ϕ(3)b⁺(2)f⁺(1), -1.0)
```
"""
function standardize_order!(g::Graph)
    for leaf in Leaves(g)
        for (i, vertex) in enumerate(leaf.vertices)
            sign, newvertex = correlator_order(vertex)
            leaf.vertices[i] = OperatorProduct(newvertex)
            leaf.factor *= sign
        end
    end
end

function remove_graph(parent::Graph{F,W}, children::Graph{F,W}) where{F,W}
    # Remove children from parent subgraphs. Currently only applies for Prod() node.
    #TODO: vertices, external, topology, factor should be changed accordingly
    return  Graph(parent.vertices;external=parent.external,type=parent.type,topology=parent.topology,subgraphs=[v for v in parent.subgraphs if !isequiv(v,children, :factor, :id)], operator = Prod(), ftype=F, wtype=W, factor=parent.factor)
end
function factorize(g::Graph{F,W}) where{F,W}
    #@assert g.operator==Sum() "factorize requires the operator to be Sum()"
    lv2pool=[] # The union of all level 2 subgraphs
    lv2_in_which=[] # For each unique level 2 subgraph, record the index of level 1 subgraphs that contains it 
    lv2_factor=[]  # Record the different factors of identical level 2 subgraphs in each level 1 subgraph that contains it 
    for (i,vi) in enumerate(g.subgraphs)
        #@assert vi.operator == Prod() "factorize requires the operator of all subgraphs to be Prod()"
        for (j,vvj) in enumerate(vi.subgraphs)
            idx = findfirst([isequiv(vvj, v, :factor, :id) for v in lv2pool])
            if isnothing(idx)
                push!(lv2pool,vvj)
                push!(lv2_in_which, [i,])
                push!(lv2_factor, [vvj.factor,])
            else
                push!(lv2_in_which[idx], i)
                push!(lv2_factor[idx], vvj.factor)                
            end
        end
    end
    # The level 2 subgraph that we factorize is the one shared by largest number of level 1 subgraph
    commonidx=findmax([length(lv2_in_which[i]) for i in 1:length(lv2_in_which)])[2]
    commongraph = lv2pool[commonidx]
    uncommonlist = [] # The union of all level 2 subgraphs, except for commongraph, from level 1 subgraphs that shares commongraph.  

    for i in lv2_in_which[commonidx]
        #TODO: when adding level 2 subgraphs, merge the identical ones with merge_factor
        #The different factors of the commongraph can not be factored out, and should go into the rest of the graphs 
        push!(uncommonlist, remove_graph(g.subgraphs[i], commongraph))
    end
    #TODO: how factor and topology propagates here still need some thinking
    uncommongraph = Graph(uncommonlist[1].vertices;external=uncommonlist[1].external,type=uncommonlist[1].type,topology=uncommonlist[1].topology,subgraphs=uncommonlist,operator = Sum(), 
                          ftype=F, wtype=W) # All subgraphs that are summed should have the same set of vertices
    refactoered_graph = Graph(g.vertices;external=g.external,type=g.type,topology=g.topology,subgraphs=[commongraph, uncommongraph], operator = Prod(), 
                              ftype=F, wtype=W,factor=1)
    # The refactorized graph should have the same set of vertices as original one
    if(length(lv2_in_which[commonidx])==length(g.subgraphs))
        # When the common factor is shared by all level 1 subgraph,
        # the node should be merged in to a product
        refactoered_graph.factor = g.factor 
        return refactoered_graph
    else
        return  Graph(g.vertices;external=g.external,type=g.type,topology=g.topology,subgraphs=vcat([refactoered_graph], [g.subgraphs[i] for i in 1:length(g.subgraphs) if i∉lv2_in_which[commonidx]]), operator = Sum(), ftype=F, wtype=W,factor=g.factor)
    end    
end


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

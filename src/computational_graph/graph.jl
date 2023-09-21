"""
    mutable struct Graph{F,W}
    
    A generic representation of a computational graph, e.g., an expression tree.

# Members:
- `id::Int`  the unique hash id to identify the diagram
- `name::Symbol`  name of the diagram
- `nodedata::Any`  holds any data to be associated with this node of the graph.
- `subgraphs::Vector{Graph{F,W}}`  vector of sub-diagrams 
- `subgraph_factors::Vector{F}`  scalar multiplicative factors associated with each subgraph. Note that the subgraph factors may be manipulated algebraically. To associate a fixed multiplicative factor with this graph which carries some semantic meaning, use the `factor` argument instead.
- `operator::DataType`  node operation. Addition and multiplication are natively supported via operators Sum and Prod, respectively. Should be a concrete subtype of `AbstractOperator`.
- `factor::F`  total scalar multiplicative factor for the diagram
- `weight::W`  the weight of this node

# Example:
```julia-repl
julia> g1 = Graph([], nodedata=1)
1:f⁺(1)|f⁻(2)=0.0

julia> g2 = Graph([], nodedata="2")
2:f⁺(3)|f⁻(4)=0.0

julia> g = Graph([g1, g2], operator=ComputationalGraphs.Sum())
3:f⁺(1)|f⁻(2)|f⁺(3)|f⁻(4)=0.0=Ⓧ (1,2)
```
"""
mutable struct Graph{F,W} <: AbstractGraph # Graph
    id::Int
    name::String # "" by default

    nodedata::Any
    subgraphs::Vector{Graph{F,W}}
    subgraph_factors::Vector{F}

    operator::DataType
    factor::F
    weight::W

    """
        function Graph(subgraphs=[]; nodedata=nothing, name="", operator::AbstractOperator=Sum(),
            ftype=_dtype.factor, wtype=_dtype.weight, factor=one(ftype), weight=zero(wtype))
        
        Create a Graph struct from a set of subgraphs with the specified node data and operation.

    # Arguments:
    - `subgraphs`  vector of sub-diagrams 
    - `subgraph_factors`  scalar multiplicative factors associated with each subgraph. Note that the subgraph factors may be manipulated algebraically. To associate a fixed multiplicative factor with this graph which carries some semantic meaning, use the `factor` argument instead.
    - `nodedata`  holds any data to be associated with this node of the graph.
    - `name`  name of the diagram
    - `operator`  node operation, i.e., Sum, Prod, or a user-defined operator `Op <: AbstractOperator`
    - `ftype`  typeof(factor)
    - `wtype`  typeof(weight)
    - `factor`  fixed scalar multiplicative factor for this diagram (e.g., a permutation sign)
    - `weight`  the weight of this node
    """
    function Graph(subgraphs::AbstractVector; subgraph_factors=one.(eachindex(subgraphs)), nodedata=nothing, name="", operator::AbstractOperator=Sum(),
        ftype=_dtype.factor, wtype=_dtype.weight, factor=one(ftype), weight=zero(wtype)
    )
        return new{ftype,wtype}(uid(), name, nodedata, subgraphs, subgraph_factors, typeof(operator), factor, weight)
    end
end

function Base.:*(g1::Graph{F,W}, c2::C) where {F,W,C}
    g = Graph([g1,]; subgraph_factors=[F(c2),],
        nodedata=g1.nodedata, operator=Prod(), ftype=F, wtype=W)
    # Merge multiplicative link
    if g1.operator == Prod && onechild(g1)
        g.subgraph_factors[1] *= g1.subgraph_factors[1]
        g.subgraphs = g1.subgraphs
    end
    return g
end

function Base.:*(c1::C, g2::Graph{F,W}) where {F,W,C}
    g = Graph([g2,]; subgraph_factors=[F(c1),],
        nodedata=g2.nodedata, operator=Prod(), ftype=F, wtype=W)
    # Merge multiplicative link
    if g2.operator == Prod && onechild(g2)
        g.subgraph_factors[1] *= g2.subgraph_factors[1]
        g.subgraphs = g2.subgraphs
    end
    return g
end

"""
    function linear_combination(g1::Graph{F,W}, g2::Graph{F,W}, c1::C, c2::C) where {F,W,C}

    Returns a graph representing the linear combination `c1*g1 + c2*g2`.
"""
function linear_combination(g1::Graph{F,W}, g2::Graph{F,W}, c1::C, c2::C) where {F,W,C}
    nodedata = union(g1.nodedata, g2.nodedata)
    g = Graph([g1, g2]; subgraph_factors=[F(c1), F(c2)],
        nodedata=nodedata, operator=Sum(), ftype=F, wtype=W)
    # Convert multiplicative links to in-place form
    if g1.operator == Prod && onechild(g1)
        g.subgraph_factors[1] *= g1.subgraph_factors[1]
        g.subgraphs[1] = g1.subgraphs[1]
    end
    if g2.operator == Prod && onechild(g2)
        g.subgraph_factors[2] *= g2.subgraph_factors[1]
        g.subgraphs[2] = g2.subgraphs[1]
    end
    return g
end

"""
    function linear_combination(graphs::Vector{Graph{F,W}}, constants::Vector{C}) where {F,W,C}

    Given a vector 𝐠 of graphs each with the same type and external/internal
    vertices and an equally-sized vector 𝐜 of constants, returns a new
    graph representing the linear combination (𝐜 ⋅ 𝐠).
"""
function linear_combination(graphs::Vector{Graph{F,W}}, constants::Vector{C}) where {F,W,C}
    nodedata = union(getproperty.(graphs, :nodedata))
    g1 = graphs[1]
    g = Graph(graphs; subgraph_factors=constants,
        nodedata=nodedata, operator=Sum(), ftype=F, wtype=W)
    # Convert multiplicative links to in-place form
    for (i, sub_g) in enumerate(g.subgraphs)
        if sub_g.operator == Prod && onechild(sub_g)
            g.subgraph_factors[i] *= sub_g.subgraph_factors[1]
            g.subgraphs[i] = sub_g.subgraphs[1]
        end
    end
    return g
end

function Base.:+(g1::Graph{F,W}, g2::Graph{F,W}) where {F,W}
    return linear_combination(g1, g2, F(1), F(1))
end

function Base.:-(g1::Graph{F,W}, g2::Graph{F,W}) where {F,W}
    return linear_combination(g1, g2, F(1), F(-1))
end

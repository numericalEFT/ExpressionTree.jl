@inline apply(::Type{Sum}, diags::Vector{Graph{F,W}}, factors::Vector{F}) where {F<:Number,W<:Number} = sum(d.weight * d.factor * f for (d, f) in zip(diags, factors))
@inline apply(::Type{Prod}, diags::Vector{Graph{F,W}}, factors::Vector{F}) where {F<:Number,W<:Number} = prod(d.weight * d.factor * f for (d, f) in zip(diags, factors))
@inline apply(o::Sum, diag::Graph{F,W}) where {F<:Number,W<:Number} = diag.weight
@inline apply(o::Prod, diag::Graph{F,W}) where {F<:Number,W<:Number} = diag.weight

@inline apply(::Type{Sum}, diags::Vector{FeynmanGraph{F,W}}, factors::Vector{F}) where {F<:Number,W<:Number} = sum(d.weight * d.factor * f for (d, f) in zip(diags, factors))
@inline apply(::Type{Prod}, diags::Vector{FeynmanGraph{F,W}}, factors::Vector{F}) where {F<:Number,W<:Number} = prod(d.weight * d.factor * f for (d, f) in zip(diags, factors))
@inline apply(o::Sum, diag::FeynmanGraph{F,W}) where {F<:Number,W<:Number} = diag.weight
@inline apply(o::Prod, diag::FeynmanGraph{F,W}) where {F<:Number,W<:Number} = diag.weight

function eval!(g::Graph{F,W}, leafmap::Dict{Int,Int}=Dict{Int,Int}(), leaf::Vector{W}=Vector{W}()) where {F,W}
    result = nothing

    for node in PostOrderDFS(g)
        if isleaf(node)
            node.weight = leaf[leafmap[node.id]]
        else
            node.weight = apply(node.operator, node.subgraphs, node.subgraph_factors)
        end
        result = node.weight * node.factor
    end
    return result
end

function eval!(g::FeynmanGraph{F,W}, leafmap::Dict{Int,Int}=Dict{Int,Int}(), leaf::Vector{W}=Vector{W}()) where {F,W}
    result = nothing

    for node in PostOrderDFS(g)
        if isleaf(node)
            node.weight = leaf[leafmap[node.id]]
        else
            node.weight = apply(node.operator, node.subgraphs, node.subgraph_factors)
        end
        result = node.weight * node.factor
    end
    return result
end

function eval!(g::Number)
    return g
end

function eval!(nothing)
    return nothing
end
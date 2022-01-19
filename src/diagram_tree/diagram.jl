# Base.hash(d::DiagramId) = hash(d) % 1000000

mutable struct Diagram{W}
    hash::Int
    name::Symbol
    id::DiagramId
    operator::Operator
    factor::W
    subdiagram::Vector{Diagram{W}}

    weight::W
    # parent::Diagram

    function Diagram(id::DiagramId, operator::Operator = Sum(), subdiagram = []; type::DataType = id.para.weightType,
        name = :none, factor = one(type), weight = zero(type))
        return new{type}(uid(), name, id, operator, factor, subdiagram, weight)
    end

    #constructor for DiagramId without a field of GenericPara
    function Diagram{W}(id::DiagramId, operator::Operator = Sum(), subdiagram = [];
        name = :none, factor = W(1), weight = W(0)) where {W}
        return new{W}(uid(), name, id, operator, factor, subdiagram, weight)
    end
end

isbare(diag::Diagram) = isempty(diag.subdiagram)

function addSubDiagram!(parent::Diagram, child::Diagram)
    for c in parent.subdiagram
        if c.id == child.id
            return false
        end
    end
    push!(parent.subdiagram, child)
end

function addSubDiagram!(parent::Diagram, child::Vector{Diagram{W}}) where {W}
    for d in child
        addSubDiagram!(parent, d)
    end
end


@inline apply(o::Sum, diags::Vector{Diagram{W}}) where {W<:Number} = sum(d.weight for d in diags)
@inline apply(o::Prod, diags::Vector{Diagram{W}}) where {W<:Number} = prod(d.weight for d in diags)
@inline apply(o::Sum, diag::Diagram{W}) where {W<:Number} = diag.weight
@inline apply(o::Prod, diag::Diagram{W}) where {W<:Number} = diag.weight

function evalDiagNode!(diag::Diagram, evalBare::Function, vargs...; kwargs...)
    if isbare(diag)
        diag.weight = evalBare(diag.id, vargs...; kwargs...) * diag.factor
    else
        diag.weight = apply(diag.operator, diag.subdiagram) * diag.factor
    end
    return diag.weight
end

function evalDiagTree!(diag::Diagram, evalBare::Function, vargs...; kwargs...)
    for d in PostOrderDFS(diag)
        evalDiagNode!(d, evalBare, vargs...; kwargs...)
    end
    return diag.weight
end

function toDict(diag::Diagram; verbose::Int, maxdepth::Int = 1)
    @assert maxdepth == 1 "deep convert has not yet been implemented!"
    # if verbose >= 1
    d = Dict{Symbol,Any}(toDict(diag.id; verbose = verbose))
    # else
    #     d = Dict{Symbol,Any}()
    # end
    d[:hash] = diag.hash
    d[:name] = diag.name
    d[:operator] = diag.operator
    d[:factor] = diag.factor
    d[:weight] = diag.weight
    d[:Diagram] = diag
    d[:id] = typeof(diag.id)
    d[:subdiagram] = Tuple(d.hash for d in diag.subdiagram)
    return d
end

function toDataFrame(diagVec::AbstractVector; verbose::Int = 0, maxdepth::Int = 1)
    # diags = []
    d = Dict{Symbol,Any}()
    k = []
    for d in diagVec
        # println(keys(toDict(d, verbose, maxdepth)))
        append!(k, keys(toDict(d, verbose = verbose, maxdepth = maxdepth)))
    end
    for f in Set(k)
        d[f] = []
    end
    # println(d)
    df = DataFrame(d)

    for d in diagVec
        dict = toDict(d, verbose = verbose, maxdepth = maxdepth)
        append!(df, dict, cols = :union)
    end
    return df
end

## Things we need to define
function AbstractTrees.children(diag::Diagram)
    return diag.subdiagram
end

## Things that make printing prettier
# AbstractTrees.printnode(io::IO, diag::Diagram) = print(io, "\u001b[32m$(diag.hash)\u001b[0m : $(diag.id)")
AbstractTrees.printnode(io::IO, diag::Diagram) = print(io, "$(diag)")

## Optional enhancements
# These next two definitions allow inference of the item type in iteration.
# (They are not sufficient to solve all internal inference issues, however.)
# Base.eltype(::Type{<:TreeIterator{BinaryNode{T}}}) where {T} = BinaryNode{T}
# Base.IteratorEltype(::Type{<:TreeIterator{BinaryNode{T}}}) where {T} = Base.HasEltype()

## Let's test it. First build a tree.
# this file is included in ComputationalGraphs.jl

"""
    function relabel!(g::FeynmanGraph, map::Dict{Int,Int})

    Relabels the quantum operators in g and its subgraphs according to `map`.
    For example, `map = {1=>2, 3=>2}`` will find all quantum operators with labels 1 and 3, and then map them to 2.

# Arguments:
- `g::FeynmanGraph`: graph to be modified
- `map`: mapping from old labels to the new ones
"""
function relabel!(g::FeynmanGraph, map::Dict{Int,Int})

    for i in eachindex(vertices(g))
        op = vertices(g)[i]
        for j in eachindex(op.operators)
            qo = op.operators[j]
            if haskey(map, qo.label)
                op.operators[j] = QuantumOperator(qo, map[qo.label])
            end
        end
    end

    for i in eachindex(g.subgraphs)
        relabel!(g.subgraphs[i], map)
    end

    return g
end

"""
    function relabel(g::FeynmanGraph, map::Dict{Int,Int})

    Returns a copy of g with quantum operators in g and its subgraphs relabeled according to `map`.
    For example, `map = {1=>2, 3=>2}` will find all quantum operators with labels 1 and 3, and then map them to 2.

# Arguments:
- `g::FeynmanGraph`: graph to be modified
- `map`: mapping from old labels to the new ones
"""
relabel(g::FeynmanGraph, map::Dict{Int,Int}) = relabel!(deepcopy(g), map)

"""
    function collect_labels(g::FeynmanGraph)

    Returns the list of sorted unique labels in graph g.

# Arguments:
- `g::FeynmanGraph`: graph to find labels for
"""
function collect_labels(g::FeynmanGraph)
    labels = Vector{Int}([])
    for i in eachindex(vertices(g))
        op = vertices(g)[i]
        for j in eachindex(op.operators)
            qo = op.operators[j]
            if !(qo.label in labels)
                push!(labels, qo.label)
            end
        end
    end

    uniqlables = sort(unique(labels))
    return uniqlables
end

"""
    function standardize_labels!(g::FeynmanGraph)

    Finds all labels involved in g and its subgraphs and 
    modifies g by relabeling in standardized order, e.g.,
    (1, 4, 5, 7, ...) ↦ (1, 2, 3, 4, ....)

# Arguments:
- `g::FeynmanGraph`: graph to be relabeled
"""
function standardize_labels!(g::FeynmanGraph)
    #TBD
    uniqlabels = collect_labels(g)
    map = Dict{Int,Int}()
    for i in eachindex(uniqlabels)
        push!(map, uniqlabels[i] => i)
    end
    return relabel!(g, map)
end

"""
    function standardize_labels!(g::FeynmanGraph)

    Finds all labels involved in g and its subgraphs and returns 
    a copy of g relabeled in a standardized order, e.g.,
    (1, 4, 5, 7, ...) ↦ (1, 2, 3, 4, ....)

# Arguments:
- `g::FeynmanGraph`: graph to be relabeled
"""
standardize_labels(g::FeynmanGraph) = standardize_labels!(deepcopy(g))

"""
    function replace_subgraph!(g::AbstractGraph, w::AbstractGraph, m::AbstractGraph)

    Modifies g by replacing the subgraph w with a new graph m.
    For Feynman diagrams, subgraphs w and m should have the same diagram type, orders, and external indices.

# Arguments:
- `g::AbstractGraph`: graph to be modified
- `w::AbstractGraph`: subgraph to replace
- `m::AbstractGraph`: new subgraph
"""
function replace_subgraph!(g::AbstractGraph, w::AbstractGraph, m::AbstractGraph)
    if g isa FeynmanGraph
        @assert w isa FeynmanGraph && m isa FeynmanGraph "Feynman diagrams should be replaced with Feynman diagrams"
        @assert isleaf(g) == false "Target parent graph cannot be a leaf"
        @assert diagram_type(w) == diagram_type(m) "Old and new subgraph should have the same diagram type"
        @assert orders(w) == orders(m) "Old and new subgraph should have the same orders"
        @assert external_indices(w) == external_indices(m) "Old and new subgraph should have the same external indices"
    end
    for node in PreOrderDFS(g)
        for (i, child) in enumerate(children(node))
            if isequiv(child, w, :id)
                node.subgraphs[i] = m
                return
            end
        end
    end
end

"""
    function replace_subgraph(g::AbstractGraph, w::AbstractGraph, m::AbstractGraph)

    Creates a modified copy of g by replacing the subgraph w with a new graph m.
    For Feynman diagrams, subgraphs w and m should have the same diagram type, orders, and external indices.

# Arguments:
- `g::AbstractGraph`: graph to be modified
- `w::AbstractGraph`: subgraph to replace
- `m::AbstractGraph`: new subgraph
"""
function replace_subgraph(g::AbstractGraph, w::AbstractGraph, m::AbstractGraph)
    if g isa FeynmanGraph
        @assert w isa FeynmanGraph && m isa FeynmanGraph "Feynman diagrams should be replaced with Feynman diagrams"
        @assert isleaf(g) == false "Target parent graph cannot be a leaf"
        @assert diagram_type(w) == diagram_type(m) "Old and new subgraph should have the same diagram type"
        @assert orders(w) == orders(m) "Old and new subgraph should have the same orders"
        @assert external_indices(w) == external_indices(m) "Old and new subgraph should have the same external indices"
    end
    g_new = deepcopy(g)
    for node in PreOrderDFS(g_new)
        for (i, child) in enumerate(children(node))
            if isequiv(child, w, :id)
                node.subgraphs[i] = m
                break
            end
        end
    end
    return g_new
end

"""
    function merge_factorless_chain!(g::AbstractGraph)

    Simplifies `g` in-place if it represents a factorless trivial unary chain. For example, +(+(+g)) ↦ g.

    Does nothing unless g has the following structure: 𝓞 --- 𝓞' --- ⋯ --- 𝓞'' ⋯ (!),
    where the stop-case (!) represents a leaf, a non-trivial unary operator 𝓞'''(g) != g,
    a node with non-unity multiplicative prefactor, or a non-unary operation.

# Arguments:
- `g::AbstractGraph`: graph to be modified
"""
function merge_factorless_chain!(g::AbstractGraph)
    while unary_istrivial(g.operator) && onechild(g) && isfactorless(g)
        child = eldest(g)
        for field in fieldnames(typeof(g))
            value = getproperty(child, field)
            setproperty!(g, field, value)
        end
    end
    return g
end

"""
    function merge_factorless_chain(g::AbstractGraph)

    Returns a simplified copy of `g` if it represents a factorless trivial unary chain.
    Otherwise, returns the original graph. For example, +(+(+g)) ↦ g.

    Does nothing unless g has the following structure: 𝓞 --- 𝓞' --- ⋯ --- 𝓞'' ⋯ (!),
    where the stop-case (!) represents a leaf, a non-trivial unary operator 𝓞'''(g) != g,
    a node with non-unity multiplicative prefactor, or a non-unary operation.

# Arguments:
- `g::AbstractGraph`: graph to be modified
"""
function merge_factorless_chain(g::AbstractGraph)
    while unary_istrivial(g.operator) && onechild(g) && isfactorless(g)
        g = eldest(g)
    end
    return g
end

"""
    function merge_chain_prefactors!(g::AbstractGraph)

    Simplifies subgraphs of g representing trivial unary chains by merging their 
    subgraph factors toward root level, e.g., 2*(3*(5*g)) + 7*(9*(h)) ↦ 30*(*(*g)) + 63*(*h). 

    Acts only on subgraphs of g with the following structure: 𝓞 --- 𝓞' --- ⋯ --- 𝓞'' ⋯ (!),
    where the stop-case (!) represents a leaf, a non-trivial unary operator 𝓞'''(g) != g, or a non-unary operation.

# Arguments:
- `g::AbstractGraph`: graph to be modified
"""
function merge_chain_prefactors!(g::AbstractGraph)
    for (i, child) in enumerate(g.subgraphs)
        total_chain_factor = 1
        while onechild(child)
            # Break case: end of trivial unary chain
            unary_istrivial(child.operator) == false && break
            # Move this subfactor to running total
            total_chain_factor *= child.subgraph_factors[1]
            child.subgraph_factors[1] = 1
            # Descend one level
            child = eldest(child)
        end
        # Update g subfactor with total factors from children
        g.subgraph_factors[i] *= total_chain_factor
    end
    return g
end

"""
    function merge_chain_prefactors(g::AbstractGraph)

    Returns a copy of g with subgraphs representing trivial unary chains simplified by merging 
    their subgraph factors toward root level, e.g., 2*(3*(5*g)) + 7*(9*(h)) ↦ 30*(*(*g)) + 63*(*h).

    Acts only on subgraphs of g with the following structure: 𝓞 --- 𝓞' --- ⋯ --- 𝓞'' ⋯ (!),
    where the stop-case (!) represents a leaf, a non-trivial unary operator 𝓞'''(g) != g, or a non-unary operation.

# Arguments:
- `g::AbstractGraph`: graph to be modified
"""
merge_chain_prefactors(g::AbstractGraph) = merge_chain_prefactors!(deepcopy(g))

"""
    function merge_chains!(g::AbstractGraph)

    Converts subgraphs of g representing trivial unary chains
    to in-place form, e.g., 2*(3*(5*g)) + 7*(9*(h)) ↦ 30*g + 63*h.

    Acts only on subgraphs of g with the following structure: 𝓞 --- 𝓞' --- ⋯ --- 𝓞'' ⋯ (!),
    where the stop-case (!) represents a leaf, a non-trivial unary operator 𝓞'''(g) != g, or a non-unary operation.

# Arguments:
- `g::AbstractGraph`: graph to be modified
"""
function merge_chains!(g::AbstractGraph)
    merge_chain_prefactors!(g)  # shift chain subgraph factors towards root level
    for sub_g in g.subgraphs    # prune factorless chain subgraphs
        merge_factorless_chain!(sub_g)
    end
    return g
end

"""
    function merge_chains(g::AbstractGraph)

    Returns a copy of a graph g with subgraphs representing trivial unary chain
    simplified to in-place form, e.g., 2*(3*(5*g)) + 7*(9*(h)) ↦ 30*g + 63*h.

    Acts only on subgraphs of g with the following structure: 𝓞 --- 𝓞' --- ⋯ --- 𝓞'' ⋯ (!),
    where the stop-case (!) represents a leaf, a non-trivial unary operator 𝓞'''(g) != g, or a non-unary operation.

# Arguments:
- `g::AbstractGraph`: graph to be modified
"""
merge_chains(g::AbstractGraph) = merge_chains!(deepcopy(g))

"""
    function merge_linear_combination(g::Graph)
   
    Returns a copy of graph g with multiplicative prefactors factorized,
    e.g., 3*g1 + 5*g2 + 7*g1 + 9*g2 ↦ 10*g1 + 14*g2. Does nothing if the
    graph g does not represent a Sum operation.

# Arguments:
- `g::Graph`: graph to be modified
"""
function merge_linear_combination(g::Graph{F,W}) where {F,W}
    if g.operator == Sum
        added = falses(length(g.subgraphs))
        subg_fac = eltype(g.subgraph_factors)[]
        subg = eltype(g.subgraphs)[]
        k = 0
        for i in eachindex(added)
            added[i] && continue
            push!(subg, g.subgraphs[i])
            push!(subg_fac, g.subgraph_factors[i])
            added[i] = true
            k += 1
            for j in (i+1):length(g.subgraphs)
                if added[j] == false && isequiv(g.subgraphs[i], g.subgraphs[j], :id)
                    added[j] = true
                    subg_fac[k] += g.subgraph_factors[j]
                end
            end
        end
        g_merged = Graph(subg; subgraph_factors=subg_fac, operator=Sum(), ftype=F, wtype=W)
        return g_merged
    else
        return g
    end
end

"""
    function merge_linear_combination(g::FeynmanGraph)
   
    Returns a copy of Feynman graph g with multiplicative prefactors factorized,
    e.g., 3*g1 + 5*g2 + 7*g1 + 9*g2 ↦ 10*g1 + 14*g2 = linear_combination(g1, g2, 10, 14).
    Returns a linear combination of unique subgraphs and their total prefactors. 
    Does nothing if the graph g does not represent a Sum operation.

# Arguments:
- `g::FeynmanGraph`: graph to be modified
"""
function merge_linear_combination(g::FeynmanGraph{F,W}) where {F,W}
    if g.operator == Sum
        added = falses(length(g.subgraphs))
        subg_fac = eltype(g.subgraph_factors)[]
        subg = eltype(g.subgraphs)[]
        k = 0
        for i in eachindex(added)
            added[i] && continue
            push!(subg, g.subgraphs[i])
            push!(subg_fac, g.subgraph_factors[i])
            added[i] = true
            k += 1
            for j in (i+1):length(g.subgraphs)
                if added[j] == false && isequiv(g.subgraphs[i], g.subgraphs[j], :id)
                    added[j] = true
                    subg_fac[k] += g.subgraph_factors[j]
                end
            end
        end
        g_merged = FeynmanGraph(subg, g.properties; subgraph_factors=subg_fac, operator=Sum(), ftype=F, wtype=W)
        return g_merged
    else
        return g
    end
end

function merge_linear_combination!(g::Graph{F,W}) where {F,W}
    if g.operator == Sum
        g_merged = merge_linear_combination(g)
        g.subgraphs = g_merged.subgraphs
        g.subgraph_factors = g_merged.subgraph_factors
    end
    return g
end

function merge_linear_combination!(g::FeynmanGraph{F,W}) where {F,W}
    if g.operator == Sum
        g_merged = merge_linear_combination(g)
        g.subgraphs = g_merged.subgraphs
        g.subgraph_factors = g_merged.subgraph_factors
    end
    return g
end

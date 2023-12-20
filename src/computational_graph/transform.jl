# this file is included in ComputationalGraphs.jl

"""
    function relabel!(g::FeynmanGraph, map::Dict{Int,Int})

    Relabels the quantum operators in `g` and its subgraphs according to `map`.
    For example, `map = {1=>2, 3=>2}`` will find all quantum operators with labels 1 and 3, and then map them to 2.

# Arguments:
- `g::FeynmanGraph`: graph to be modified
- `map`: mapping from old labels to the new ones
"""
function relabel!(g::FeynmanGraph, map::Dict{Int,Int})
    for i in eachindex(vertices(g))
        op = vertex(g, i)
        for j in eachindex(op.operators)
            qo = op.operators[j]
            if haskey(map, qo.label)
                op.operators[j] = QuantumOperator(qo, map[qo.label])
            end
        end
    end

    for i in eachindex(subgraphs(g))
        relabel!(subgraph(g, i), map)
    end
    return g
end

"""
    function relabel(g::FeynmanGraph, map::Dict{Int,Int})

    Returns a copy of `g` with quantum operators in `g` and its subgraphs relabeled according to `map`.
    For example, `map = {1=>2, 3=>2}` will find all quantum operators with labels 1 and 3, and then map them to 2.

# Arguments:
- `g::FeynmanGraph`: graph to be modified
- `map`: mapping from old labels to the new ones
"""
relabel(g::FeynmanGraph, map::Dict{Int,Int}) = relabel!(deepcopy(g), map)

"""
    function collect_labels(g::FeynmanGraph)

    Returns the list of sorted unique labels in graph `g`.

# Arguments:
- `g::FeynmanGraph`: graph to find labels for
"""
function collect_labels(g::FeynmanGraph)
    labels = Vector{Int}([])
    for i in eachindex(vertices(g))
        op = vertex(g, i)
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

    Finds all labels involved in `g` and its subgraphs and 
    modifies `g` by relabeling in standardized order, e.g.,
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

    Finds all labels involved in `g` and its subgraphs and returns 
    a copy of `g` relabeled in a standardized order, e.g.,
    (1, 4, 5, 7, ...) ↦ (1, 2, 3, 4, ....)

# Arguments:
- `g::FeynmanGraph`: graph to be relabeled
"""
standardize_labels(g::FeynmanGraph) = standardize_labels!(deepcopy(g))

"""
    function replace_subgraph!(g::AbstractGraph, w::AbstractGraph, m::AbstractGraph)

    Modifies `g` by replacing the subgraph `w` with a new graph `m`.
    For Feynman diagrams, subgraphs `w` and `m` should have the same diagram type, orders, and external indices.

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
        for (i, sub_g) in enumerate(subgraphs(node))
            if isequiv(sub_g, w, :id)
                set_subgraph!(node, m, i)
                return
            end
        end
    end
end

"""
    function replace_subgraph(g::AbstractGraph, w::AbstractGraph, m::AbstractGraph)

    Creates a modified copy of `g` by replacing the subgraph `w` with a new graph `m`.
    For Feynman diagrams, subgraphs `w` and `m` should have the same diagram type, orders, and external indices.

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
        for (i, sub_g) in enumerate(subgraphs(node))
            if isequiv(sub_g, w, :id)
                set_subgraph!(node, m, i)
                break
            end
        end
    end
    return g_new
end

"""
    function flatten_chains!(g::AbstractGraph)

    Recursively flattens chains of subgraphs within the given graph `g` by merging certain trivial unary subgraphs 
    into their parent graphs in the in-place form.

    Acts only on subgraphs of `g` with the following structure: 𝓞 --- 𝓞' --- ⋯ --- 𝓞'' ⋯ (!),
    where the stop-case (!) represents a leaf, a non-trivial unary operator 𝓞'''(g) != g, or a non-unary operation.

# Arguments:
- `g::AbstractGraph`: graph to be modified
"""
function flatten_chains!(g::AbstractGraph)
    for (i, sub_g) in enumerate(subgraphs(g))
        if unary_istrivial(sub_g) && onechild(sub_g)
            flatten_chains!(sub_g)
            new_factor = subgraph_factor(g, i) * subgraph_factor(sub_g)
            set_subgraph_factor!(g, new_factor, i)
            set_subgraph!(g, eldest(sub_g), i)
        end
    end
    return g
end

"""
    function flatten_chains(g::AbstractGraph) 

    Recursively flattens chains of subgraphs within a given graph `g` by merging certain trivial unary subgraphs into their parent graphs,
    This function returns a new graph with flatten chains, derived from the input graph `g` remaining unchanged.

# Arguments:
- `g::AbstractGraph`: graph to be modified
"""
flatten_chains(g::AbstractGraph) = flatten_chains!(deepcopy(g))

"""
    function remove_zero_valued_subgraphs!(g::AbstractGraph)

    Removes zero-valued (zero subgraph_factor) subgraph(s) of a computational graph `g`. If all subgraphs are zero-valued, the first one (`eldest(g)`) will be retained.

# Arguments:
- `g::AbstractGraph`: graph to be modified
"""
function remove_zero_valued_subgraphs!(g::AbstractGraph)
    if isleaf(g) || isbranch(g)  # we must retain at least one subgraph
        return g
    end
    subg = collect(subgraphs(g))
    subg_fac = collect(subgraph_factors(g))
    zero_sgf = zero(subg_fac[1])  # F(0)
    # Find subgraphs with all-zero subgraph_factors and propagate subfactor one level up
    for (i, sub_g) in enumerate(subg)
        if has_zero_subfactors(sub_g)
            subg_fac[i] = zero_sgf
        end
    end
    # Remove marked zero subgraph factor subgraph(s) of g
    mask_zeros = findall(x -> x != zero(x), subg_fac)
    if isempty(mask_zeros)
        mask_zeros = [1]  # retain eldest(g) if all subfactors are zero
    end
    set_subgraphs!(g, subg[mask_zeros])
    set_subgraph_factors!(g, subg_fac[mask_zeros])
    return g
end

"""
    function remove_zero_valued_subgraphs(g::AbstractGraph)

    Returns a copy of graph `g` with zero-valued (zero subgraph_factor) subgraph(s) removed.
    If all subgraphs are zero-valued, the first one (`eldest(g)`) will be retained.

# Arguments:
- `g::AbstractGraph`: graph to be modified
"""
remove_zero_valued_subgraphs(g::AbstractGraph) = remove_zero_valued_subgraphs!(deepcopy(g))

"""
    function merge_linear_combination!(g::AbstractGraph)
   
    Modifies a computational graph `g` by factorizing multiplicative prefactors, e.g.,
    3*g1 + 5*g2 + 7*g1 + 9*g2 ↦ 10*g1 + 14*g2 = linear_combination(g1, g2, 10, 14).
    Returns a linear combination of unique subgraphs and their total prefactors. 
    Does nothing if the graph `g` does not represent a Sum operation.

# Arguments:
- `g::AbstractGraph`: graph to be modified
"""
function merge_linear_combination!(g::AbstractGraph)
    if operator(g) == Sum
        subg = subgraphs(g)
        subg_fac = subgraph_factors(g)
        added = falses(length(subg))
        merged_subg = eltype(subg)[]
        merged_subg_fac = eltype(subg_fac)[]
        k = 0
        for i in eachindex(added)
            added[i] && continue
            push!(merged_subg, subg[i])
            push!(merged_subg_fac, subg_fac[i])
            added[i] = true
            k += 1
            for j in (i+1):length(subg)
                if added[j] == false && isequiv(subg[i], subg[j], :id)
                    added[j] = true
                    merged_subg_fac[k] += subg_fac[j]
                end
            end
        end
        set_subgraphs!(g, merged_subg)
        set_subgraph_factors!(g, merged_subg_fac)
    end
    return g
end

"""
    function merge_linear_combination(g::AbstractGraph)
   
    Returns a copy of computational graph `g` with multiplicative prefactors factorized,
    e.g., 3*g1 + 5*g2 + 7*g1 + 9*g2 ↦ 10*g1 + 14*g2 = linear_combination(g1, g2, 10, 14).
    Returns a linear combination of unique subgraphs and their total prefactors. 
    Does nothing if the graph `g` does not represent a Sum operation.

# Arguments:
- `g::AbstractGraph`: graph to be modified
"""
merge_linear_combination(g::AbstractGraph) = merge_linear_combination!(deepcopy(g))

"""
    function merge_multi_product!(g::Graph{F,W}) where {F,W}

    Merge multiple products within a computational graph `g` if they share the same operator (`Prod`).
    If `g.operator == Prod`, this function will merge `N` identical subgraphs into a single subgraph with a power operator `Power(N)`. 
    The function ensures each unique subgraph is counted and merged appropriately, preserving any distinct subgraph_factors associated with them.

# Arguments:
- `g::Graph`: graph to be modified

# Returns
- A merged computational graph with potentially fewer subgraphs if there were repeating subgraphs 
  with the `Prod` operator. If the input graph's operator isn't `Prod`, the function returns the input graph unchanged.
"""
function merge_multi_product!(g::Graph{F,W}) where {F,W}
    if g.operator == Prod
        unique_graphs = Vector{Graph{F,W}}()
        unique_factors = F[]
        repeated_counts = Int[]
        for (idx, subg) in enumerate(g.subgraphs)
            loc = findfirst(isequal(subg), unique_graphs)
            if isnothing(loc)
                push!(unique_graphs, subg)
                push!(unique_factors, g.subgraph_factors[idx])
                push!(repeated_counts, 1)
            else
                unique_factors[loc] *= g.subgraph_factors[idx]
                repeated_counts[loc] += 1
            end
        end

        if length(unique_factors) == 1
            g.subgraphs = unique_graphs
            g.subgraph_factors = unique_factors
            g.operator = typeof(Power(repeated_counts[1]))
        else
            _subgraphs = Vector{Graph{F,W}}()
            for (idx, g) in enumerate(unique_graphs)
                if repeated_counts[idx] == 1
                    push!(_subgraphs, g)
                else
                    push!(_subgraphs, Graph([g], operator=Power(repeated_counts[idx]), ftype=F, wtype=W))
                end
            end
            g.subgraphs = _subgraphs
            g.subgraph_factors = unique_factors
            g.operator = Prod
        end
    end
    return g
end

"""
    function merge_multi_product(g::Graph{F,W}) where {F,W}

    Returns a copy of computational graph `g` with multiple products merged if they share the same operator (`Prod`).
    If `g.operator == Prod`, this function will merge `N` identical subgraphs into a single subgraph with a power operator `Power(N)`. 
    The function ensures each unique subgraph is counted and merged appropriately, preserving any distinct subgraph_factors associated with them.

# Arguments:
- `g::Graph`: graph to be modified

# Returns
- A merged computational graph with potentially fewer subgraphs if there were repeating subgraphs 
  with the `Prod` operator. If the input graph's operator isn't `Prod`, the function returns the input graph unchanged.
"""
merge_multi_product(g::AbstractGraph) = merge_multi_product!(deepcopy(g))

function _ops_to_string(ops::Vector{OperatorProduct})
    strs = [string(o) for o in ops]
    return join(strs, "|")
end

function _ops_to_repr(ops::Vector{OperatorProduct})
    reprs = [repr(o) for o in ops]
    return join(reprs, "|")
end

function short(factor, ignore=nothing)
    if isnothing(ignore) == false && applicable(isapprox, factor, ignore) && factor ≈ ignore
        return ""
    end
    str = "$(factor)"
    if factor isa Float64
        return length(str) <= 4 ? str : @sprintf("%6.3e", factor)
    elseif factor isa Vector{Float64}
        return length(str) <= 4 ? str : reduce(*, [@sprintf("%6.3e", f) for f in factor])
    else
        return str
    end
end

function short_orders(orders)
    orders_no_trailing_zeros = ""
    idx_last_set = findlast(x -> x != 0, orders)
    if isnothing(idx_last_set) == false
        orders_no_trailing_zeros *= string(orders[1:idx_last_set])
    end
    return orders_no_trailing_zeros
end
  
function _namestring(graph::AbstractGraph)
    return isnothing(name(graph)) ? "" : string(name(graph))
end

function _namestring(graph::FeynmanGraph)
    return isempty(name(graph)) ? "" : string(name(graph), ", ")
end

function _idstring(graph::AbstractGraph)
    return _namestring(graph)
end

function _idstring(graph::FeynmanGraph)
    return string(_namestring(graph), _ops_to_string(vertices(graph)))
end

_idrepr(graph::AbstractGraph) = _idstring(graph)

function _idrepr(graph::FeynmanGraph)
    return string(_namestring(graph), _ops_to_repr(vertices(graph)))
end

function _propertystring(graph::AbstractGraph)
    return isnothing(properties(graph)) ? "" : string(properties(graph))
end

function _weightstring(graph::AbstractGraph)
    if isleaf(graph)
        return "$(short(weight(graph)))"
    end
    typestr = join(["$(id(g))" for g in subgraphs(graph)], ",")
    return "$(operator(graph))($(typestr))=$(short(weight(graph)))"
end

function _weightrepr(graph::AbstractGraph)
    if isleaf(graph)
        return "$(short(weight(graph)))"
    end
    typestr = join(["$(id(g))" for g in subgraphs(graph)], ",")
    return "$(repr(operator(graph)))($(typestr))=$(short(weight(graph)))"
end

function _stringrep(graph::AbstractGraph; color=false, plain=false)
    if color
        idprefix = "\u001b[32m$(id(graph))\u001b[0m: "
    else
        idprefix = string(id(graph), ": ")
    end
    idsuffix = plain ? _idstring(graph) : _idrepr(graph)

    propertystr = _propertystring(graph) * short_orders(orders(graph))
    if isempty(idsuffix) == false && isempty(propertystr) == false
        idsuffix *= ", "
    end
    idsuffix *= propertystr
    
    wstr = plain ? _weightstring(graph) : _weightrepr(graph)
    if isempty(idsuffix) == false
        wstr = "=" * wstr
    end
    return "$(idprefix)$(idsuffix)$(wstr)"
end

"""
    print(io::IO, graph::AbstractGraph)

    Write an un-decorated text representation of an AbstractGraph `graph` to the output stream `io`.
"""
function Base.print(io::IO, graph::AbstractGraph)
    print(io, _stringrep(graph; plain=true))
end

"""
    show(io::IO, graph::AbstractGraph; kwargs...)

    Write a text representation of an AbstractGraph `graph` to the output stream `io`.
"""
function Base.show(io::IO, graph::AbstractGraph; kwargs...)
    print(io, _stringrep(graph))
end
Base.show(io::IO, ::MIME"text/plain", graph::AbstractGraph; kwargs...) = Base.show(io, graph; kwargs...)

"""
    function plot_tree(graph::AbstractGraph; verbose = 0, maxdepth = 6)

    Visualize the computational graph as a tree using ete3 python package

#Arguments
- `graph::AbstractGraph`        : the computational graph struct to visualize
- `verbose=0`   : the amount of information to show
- `maxdepth=6`  : deepest level of the computational graph to show
"""
function plot_tree(graph::AbstractGraph; verbose=0, maxdepth=6)

    # pushfirst!(PyVector(pyimport("sys")."path"), @__DIR__) #comment this line if no need to load local python module
    ete = PyCall.pyimport("ete3")

    function treeview(node, level, t=ete.Tree(name=" "))
        if level > maxdepth
            return
        end
        name = _stringrep(node)
        nt = t.add_child(name=name)

        if length(subgraphs(node)) > 0
            name_face = ete.TextFace(nt.name, fgcolor="black", fsize=10)
            nt.add_face(name_face, column=0, position="branch-top")
            for child in subgraphs(node)
                treeview(child, level + 1, nt)
            end
        end

        return t
    end

    t = treeview(graph, 1)

    # NOTE: t.set_style does not update the original PyObject as expected, i.e.,
    #       `t.set_style(ete.NodeStyle(bgcolor="Khaki"))` does not modify t.
    #
    # The low-level approach circumvents this by directly updating the original PyObject `t."img_style"`
    PyCall.set!(t."img_style", "bgcolor", "Khaki")

    ts = ete.TreeStyle()
    ts.show_leaf_name = true
    # ts.show_leaf_name = True
    # ts.layout_fn = my_layout
    ####### show tree vertically ############
    # ts.rotation = 90 #show tree vertically

    ####### show tree in an arc  #############
    # ts.mode = "c"
    # ts.arc_start = -180
    # ts.arc_span = 180
    # t.write(outfile="/home/kun/test.txt", format=8)
    t.show(tree_style=ts)
end
function plot_tree(graphs::Vector{<:AbstractGraph}; kwargs...)
    for graph in graphs
        plot_tree(graph; kwargs...)
    end
end

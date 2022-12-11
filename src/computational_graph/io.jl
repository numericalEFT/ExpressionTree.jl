# function toDict(diag::Graph; maxdepth::Int)
#     @assert maxdepth == 1 "deep convert has not yet been implemented!"

#     d = Dict{Symbol,Any}()
#     d[:hash] = diag.hash
#     d[:id] = diag.id
#     d[:name] = diag.name
#     d[:diagram] = diag
#     d[:subgraphs] = Tuple(d.hash for d in diag.subgraphs)
#     d[:operator] = diag.operator
#     d[:factor] = diag.factor
#     d[:weight] = diag.weight

#     return d
# end

function _addkey!(dict, key, val)
    @assert haskey(dict, key) == false "key already exists!"
    dict[key] = val
end

function _DiagtoDict!(dict::Dict{Symbol,Any}, diagVec::Vector{Graph{W}}; maxdepth::Int) where {W}
    @assert maxdepth == 1 "deep convert has not yet been implemented!"
    _addkey!(dict, :hash, [diag.hash for diag in diagVec])
    _addkey!(dict, :name, [diag.name for diag in diagVec])
    _addkey!(dict, :graph, diagVec)
    _addkey!(dict, :subgraphs, [Tuple(d.hash for d in diag.subgraphs) for diag in diagVec])
    _addkey!(dict, :operator, [diag.operator for diag in diagVec])
    _addkey!(dict, :factor, [diag.factor for diag in diagVec])
    _addkey!(dict, :weight, [diag.weight for diag in diagVec])
    return dict
end

# function toDict(v::GraphId)
#     d = Dict{Symbol,Any}()
#     for field in fieldnames(typeof(v))
#         data = getproperty(v, field)
#         #DataFrame will expand a vector into multiple rows. To prevent it, we transform all vectors into tuples
#         d[field] = data isa AbstractVector ? Tuple(data) : data
#     end
#     return d
# end

function _vec2tup(data)
    return data isa AbstractVector ? Tuple(data) : data
end

function _IdstoDict!(dict::Dict{Symbol,Any}, diagVec::Vector{Graph{W}}, idkey::Symbol) where {W}
    sameId = all(x -> (typeof(x.id) == typeof(diagVec[1].id)), diagVec)
    if sameId
        data = [_vec2tup(getproperty(diagVec[1].id, idkey)),]
        for idx in 2:length(diagVec)
            push!(data, _vec2tup(getproperty(diagVec[idx].id, idkey)))
        end
    else
        data = Vector{Any}()
        for diag in diagVec
            if hasproperty(diag.id, idkey)
                tup = _vec2tup(getproperty(diag.id, idkey))
                # println(tup)
                push!(data, tup)
            else
                push!(data, missing)
            end
        end
    end
    _addkey!(dict, idkey, data)
    return dict
end

function toDataFrame(diagVec::AbstractVector, idkey::Symbol; maxdepth::Int=1)
    if idkey == :all || idkey == :All
        names = Set{Symbol}()
        for diag in diagVec
            for field in fieldnames(typeof(diag.id))
                push!(names, field)
            end
        end
        return toDataFrame(diagVec, collect(names); maxdepth=maxdepth)
    else
        return toDataFrame(diagVec, [idkey,]; maxdepth=maxdepth)
    end
end

function toDataFrame(diagVec::AbstractVector, idkey=Vector{Symbol}(); maxdepth::Int=1)
    if isempty(diagVec)
        return DataFrame()
    end
    d = Dict{Symbol,Any}()
    _DiagtoDict!(d, diagVec, maxdepth=maxdepth)

    idkey = isnothing(idkey) ? Vector{Symbol}() : collect(idkey)
    if isempty(idkey) == false
        for _key in idkey
            _IdstoDict!(d, diagVec, _key)
        end
    end
    df = DataFrame(d, copycols=false)
    # df = DataFrame(d)
    return df
end

# function toDataFrame(diagVec::AbstractVector; expand::Bool=false, maxdepth::Int=1)
#     vec_of_diag_dict = [toDict(d, maxdepth=maxdepth) for d in diagVec]
#     names = Set(reduce(union, keys(d) for d in vec_of_diag_dict))
#     if expand
#         vec_of_id_dict = [toDict(d.id) for d in diagVec]
#         idnames = Set(reduce(union, keys(d) for d in vec_of_id_dict))
#         @assert isempty(intersect(names, idnames)) "collision of diagram names $names and id names $idnames"
#         names = union(names, idnames)

#         for (di, d) in enumerate(vec_of_diag_dict)
#             merge!(d, vec_of_id_dict[di]) #add id dict into the diagram dict
#         end
#     end
#     # println(names)
#     df = DataFrame([name => [] for name in names])

#     for dict in vec_of_diag_dict
#         append!(df, dict, cols=:union)
#     end
#     return df
# end

function _ops_to_str(ops::Vector{OperatorProduct})
    strs = ["$(o)" for o in ops]
    return join(strs, "|")
end

function _summary(diag::Graph{W}, color=true) where {W}

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

    namestr = isempty(diag.name) ? "" : "-$(diag.name)"
    idstr = "$(diag.id)$namestr:$(_ops_to_str(diag.vertices))"
    fstr = short(diag.factor, one(diag.factor))
    wstr = short(diag.weight)
    # =$(node.weight*(2π)^(3*node.id.para.innerLoopNum))

    if length(diag.subgraphs) == 0
        return isempty(fstr) ? "$idstr=$wstr" : "$(idstr)⋅$(fstr)=$wstr"
    else
        return "$idstr=$wstr=$fstr$(diag.operator) "
    end
end

"""
    show(io::IO, g::Graph)

    Write a text representation of `Graph` to the output stream `io`.
"""
function Base.show(io::IO, diag::Graph)
    if length(diag.subgraphs) == 0
        typestr = ""
    else
        typestr = join(["$(d.id)" for d in diag.subgraphs], ",")
        typestr = "($typestr)"
    end
    print(io, "$(_summary(diag, true))$typestr")
end

# function Base.show(io::IO, g::Graph)
#     #TODO: improve a text representation of Graph to the output stream.
#     if isempty(g.name)
#         print(io, "$(g.id): $(g.type) graph from $(_ops_to_str(g.vertices))")
#     else
#         print(io, "$(g.id), $(g.name): $(g.type) graph from $(_ops_to_str(g.vertices))")
#     end
# end
Base.show(io::IO, ::MIME"text/plain", g::Graph) = Base.show(io, g)


"""
    function plot_tree(diag::Graph; verbose = 0, maxdepth = 6)

    Visualize the diagram tree using ete3 python package

#Arguments
- `diag`        : the Graph struct to visualize
- `verbose=0`   : the amount of information to show
- `maxdepth=6`  : deepest level of the diagram tree to show
"""
function plot_tree(diag::Graph; verbose=0, maxdepth=6)

    # pushfirst!(PyVector(pyimport("sys")."path"), @__DIR__) #comment this line if no need to load local python module
    ete = PyCall.pyimport("ete3")

    function treeview(node, level, t=ete.Tree(name=" "))
        if level > maxdepth
            return
        end
        nt = t.add_child(name="$(_summary(node, false))")

        if length(node.subgraphs) > 0
            name_face = ete.TextFace(nt.name, fgcolor="black", fsize=10)
            nt.add_face(name_face, column=0, position="branch-top")
            for child in node.subgraphs
                treeview(child, level + 1, nt)
            end
        end

        return t
    end

    t = treeview(diag, 1)

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
function plot_tree(diags::Vector{Graph{W}}; kwargs...) where {W}
    for diag in diags
        plot_tree(diag; kwargs...)
    end
end
function plot_tree(df::DataFrame; kwargs...)
    plot_tree(df.diagram; kwargs...)
end
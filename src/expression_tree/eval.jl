# function warn_type(diag::Diagrams, loopVar, siteVar, evalPropagator, evalNodeFactor = nothing, root = diag.root)
#     @code_warntype evalNaive!(diag, loopVar, siteVar, evalPropagator, evalNodeFactor, root)
# end

function evalNaive!(diag::Diagrams, loopVar, siteVar, eval, evalNodeFactor = nothing, root = diag.root; kwargs...)
    loopPool = diag.basisPool
    propagatorPool = diag.propagatorPool
    tree = diag.nodePool
    pweight = propagatorPool.current
    tweight = tree.current

    # calculate new loop
    update(loopPool, loopVar)

    #TODO: right now we mannully unroll the pools, later it should be automated

    #calculate propagators
    # println(propagatorPool)
    for (idx, p) in enumerate(propagatorPool)
        pweight[idx] = eval(p.para, current(loopPool, p.loopIdx), p.siteBasis, siteVar) * p.factor
    end

    #calculate diagram tree
    NodeWeightType = eltype(tree.current)
    for (ni, node) in enumerate(tree.object)
        if node.operation == MUL
            if isempty(node.propagators) == false
                tweight[ni] = prod(pweight[pidx] for pidx in node.propagators)
            else
                tweight[ni] = NodeWeightType(1)
            end
            for nidx in node.childNodes
                tweight[ni] *= tweight[nidx]
            end

        elseif node.operation == ADD
            if isempty(node.propagators) == false
                tweight[ni] = sum(pweight[pidx] for pidx in node.propagators)
            else
                tweight[ni] = NodeWeightType(0)
            end
            for nidx in node.childNodes
                tweight[ni] += tweight[nidx]
            end
        else
            error("not implemented!")
        end
        tweight[ni] *= node.factor
        if isnothing(evalNodeFactor) == false
            tweight[ni] *= NodeWeightType(evalNodeFactor(node, loop, siteVar, diag; kwargs...))
        end
    end

    # println("tree root", root)
    # return tree.current[root]
    # return view(tree.current, root)
end
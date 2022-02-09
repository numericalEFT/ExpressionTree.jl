# function warn_type(diag::Diagrams, loopVar, siteVar, evalPropagator, evalNodeFactor = nothing, root = diag.root)
#     @code_warntype evalNaive!(diag, loopVar, siteVar, evalPropagator, evalNodeFactor, root)
# end

function evalNaive!(diag::ExpressionTree, loopVar, siteVar, eval = DiagTree.eval)
    loopPool = diag.loopBasis
    tree = diag.node
    tweight = tree.current

    # calculate new loop
    update(loopPool, loopVar)

    #calculate diagram tree
    for (ni, node) in enumerate(tree.object)
        if isempty(node.children)
            tweight[ni] = eval(node.para, current(loopPool, node.loopidx), node.siteidx, siteVar) * node.factor
        else
            if node.operation == MUL
                tweight[ni] = node.factor
                for nidx in node.children
                    tweight[ni] *= tweight[nidx]
                end

            elseif node.operation == ADD
                tweight[ni] = 0.0
                for nidx in node.children
                    tweight[ni] += tweight[nidx]
                end
                tweight[ni] *= node.factor
            else
                error("not implemented!")
            end
        end
    end
end
using FeynmanDiagram: ComputationalGraphs as Graphs

@testset verbose = true "Graph" begin
    V = [interaction(𝑓⁺(1)𝑓⁻(2)𝑓⁺(3)𝑓⁻(4)), interaction(𝑓⁺(5)𝑓⁺(6)𝑓⁻(7)𝑓⁻(8)),
        external_vertex(𝑓⁺(9)), external_vertex(𝑓⁺(10))]
    g1 = Graph(V; topology=[[2, 6], [3, 7], [4, 9], [8, 10]],
        external=[1, 5, 9, 10], hasLeg=[false, false, true, true])
    g2 = g1 * 2
    @testset "Graph equivalence" begin
        g1p = Graph(V, topology=[[2, 6], [3, 7], [4, 9], [8, 10]],
            external=[1, 5, 9, 10], hasLeg=[false, false, true, true])
        g2p = Graph(V, topology=[[2, 6], [3, 7], [4, 9], [8, 10]],
            external=[1, 5, 9, 10], hasLeg=[false, false, true, true], factor=2)
        # Test equivalence modulo fields id/factor
        @test isequiv(g1, g1p) == false
        @test isequiv(g1, g2p, :id) == false
        @test isequiv(g1, g2p, :factor) == false
        @test isequiv(g1, g1p, :id)
        @test isequiv(g1, g2p, :id, :factor)
        # Test inequivalence when subgraph lengths are different
        t = g1 + g1
        @test isequiv(t, g1, :id) == false
    end
    @testset "Scalar multiplication" begin
        @test vertices(g2) == vertices(g1)
        println(external(g2))
        println(external(g1))
        @test external(g2) == external(g1)
        @test g2.subgraph_factors == [2]
        @test g2.operator == Graphs.Prod
        g2 = 2g1
        @test vertices(g2) == vertices(g1)
        @test external(g2) == external(g1)
        @test g2.subgraph_factors == [2]
        @test g2.operator == Graphs.Prod
    end
    @testset "Graph addition" begin
        g3 = g1 + g2
        @test vertices(g3) == vertices(g1)
        @test external(g3) == external(g1)
        @test g3.factor == 1
        @test g3.subgraphs == [g1, g2]
        @test g3.subgraph_factors == [1, 1]
        @test g3.subgraphs[1].subgraph_factors == g1.subgraph_factors
        @test g3.subgraphs[2].subgraph_factors == [2]
        @test g3.operator == Graphs.Sum
    end
    @testset "Graph subtraction" begin
        g4 = g1 - g2
        @test vertices(g4) == vertices(g1)
        @test external(g4) == external(g1)
        @test g4.factor == 1
        @test g4.subgraphs == [g1, g2]
        @test g4.subgraph_factors == [1, -1]
        @test g4.subgraphs[1].subgraph_factors == g1.subgraph_factors
        @test g4.subgraphs[2].subgraph_factors == [2]
        @test g4.subgraphs[2].subgraphs[1].factor == 1
        @test g4.operator == Graphs.Sum
    end
    @testset "Linear combinations" begin
        # Binary form
        g5 = 3g1 + 5g2
        g5lc = linear_combination(g1, g2, 3, 5)
        @test g5.subgraph_factors == [1, 1]
        @test [g.subgraph_factors[1] for g in g5.subgraphs] == [3, 10]
        @test g5lc.subgraphs == [g1, g2]
        @test g5lc.subgraph_factors == [3, 5]
        # TODO: Requires graph optimization inplace_prod on g5
        # @test isequiv(simplify_subfactors(g5), g5lc, :id)
        # Vector form
        g6lc = linear_combination([g1, g2, g5, g2, g1], [3, 5, 7, 9, 11])
        @test g6lc.subgraphs == [g1, g2, g5, g2, g1]
        @test g6lc.subgraph_factors == [3, 5, 7, 9, 11]
    end
    @testset "Multiplicative chains" begin
        g6 = 7 * (5 * (3 * (2 * g1)))
        @test g6.subgraph_factors == [210]
        @test g6.subgraphs[1].subgraphs == g1.subgraphs
        @test g6.subgraphs[1].subgraph_factors == g1.subgraph_factors
        g7 = (((g1 * 2) * 3) * 5) * 7
        @test g7.subgraph_factors == [210]
        @test g7.subgraphs[1].subgraphs == g1.subgraphs
        @test g7.subgraphs[1].subgraph_factors == g1.subgraph_factors
    end
end

@testset verbose = true "Graph Operations" begin
    @testset "relabel" begin
        # construct a graph
        V = [𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6), 𝑓⁺(7)𝑓⁻(8)𝜙(9)]
        g1 = feynman_diagram(interaction.(V), [[1, 5], [3, 9], [4, 8]])

        map = Dict(3 => 1, 4 => 1, 5 => 1, 9 => 1, 8 => 1)
        g2 = relabel(g1, map)
        uniqlabels = Graphs.collect_labels(g2)
        @test uniqlabels == [1, 2, 6, 7]

        map = Dict([i => 1 for i in 2:9])
        g3 = relabel(g1, map)
        uniqlabels = Graphs.collect_labels(g3)
        @test uniqlabels == [1,]
    end
    @testset "standardize labels" begin
        V = [𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6), 𝑓⁺(7)𝑓⁻(8)𝜙(9), 𝑓⁺(10)]
        g1 = feynman_diagram([interaction.(V[1:3]); external_vertex(V[end])], [[1, 5], [3, 9], [4, 8], [2, 10]])

        map = Dict([i => (11 - i) for i in 1:5])
        g2 = relabel(g1, map)

        g3 = standardize_labels(g2)
        uniqlabels = Graphs.collect_labels(g3)
        @test uniqlabels == [1, 2, 3, 4, 5]
    end
    @testset "replace subgraph" begin
        V2 = [external_vertex(𝜙(1)), interaction(𝜙(2)𝜙(3)), external_vertex(𝜙(4))]
        g1 = feynman_diagram(V2, [[1, 2], [3, 4]])
        g2 = feynman_diagram(V2, [[1, 3], [2, 4]])
        g3 = feynman_diagram(V2, [[1, 4], [2, 3]])
        gsum = g2 + g3
        groot = g1 + gsum
        replace_subgraph!(groot, g2, g3)
        gnew = replace_subgraph(groot, g2, g3)
        @test isequiv(gsum.subgraphs[1], gsum.subgraphs[2])
    end
    @testset "prune trivial unary operations" begin
        g1 = propagator(𝑓⁺(1)𝑓⁻(2))
        # +g1
        g2 = Graph([g1,]; vertices=g1.vertices, external=g1.external,
            hasLeg=g1.hasLeg, type=g1.type(), operator=Graphs.Sum())
        # +(+g1)
        g3 = Graph([g2,]; vertices=g2.vertices, external=g2.external,
            hasLeg=g2.hasLeg, type=g2.type(), operator=Graphs.Sum())
        # +2(+g1)
        g3p = Graph([g2,]; vertices=g2.vertices, external=g2.external, hasLeg=g2.hasLeg,
            subgraph_factors=[2,], type=g2.type(), operator=Graphs.Sum())
        # +(+(+g1))
        g4 = Graph([g3,]; vertices=g3.vertices, external=g3.external,
            hasLeg=g3.hasLeg, type=g3.type(), operator=Graphs.Sum())
        # +(+2(+g1))
        g4p = Graph([g3p,]; vertices=g3p.vertices, external=g3p.external,
            hasLeg=g3p.hasLeg, type=g3p.type(), operator=Graphs.Sum())
        @test Graphs.unary_istrivial(Graphs.Prod)
        @test Graphs.unary_istrivial(Graphs.Sum)
        @test prune_trivial_unary(g2) == g1
        @test prune_trivial_unary(g3) == g1
        @test prune_trivial_unary(g4) == g1
        @test prune_trivial_unary(g3p) == g3p
        @test prune_trivial_unary(g4p) == g3p
        # 𝓞(g1), where 𝓞 is a non-trivial unary operation
        struct O <: Graphs.AbstractOperator end
        g5 = Graph([g1,]; vertices=g1.vertices, external=g1.external,
            hasLeg=g1.hasLeg, type=g1.type(), operator=O())
        @test Graphs.unary_istrivial(O) == false
        @test prune_trivial_unary(g5) == g5
    end
    g1 = propagator(𝑓⁻(1)𝑓⁺(2))
    g2 = Graph([g1,]; topology=g1.topology, vertices=g1.vertices, external=g1.external,
        hasLeg=g1.hasLeg, subgraph_factors=[5,], type=g1.type(), operator=Graphs.Prod())
    g3 = Graph([g2,]; topology=g2.topology, vertices=g2.vertices, external=g2.external,
        hasLeg=g2.hasLeg, subgraph_factors=[3,], type=g2.type(), operator=Graphs.Prod())
    # g = 2*(3*(5*g1))
    g = Graph([g3,]; topology=g3.topology, vertices=g3.vertices, external=g3.external,
        hasLeg=g3.hasLeg, subgraph_factors=[2,], type=g3.type(), operator=Graphs.Prod())
    # gp = 2*(3*(g1 + 5*g1))
    g2p = g1 + g2
    g3p = Graph([g2p,]; topology=g2p.topology, vertices=g2p.vertices, external=g2p.external,
        hasLeg=g2p.hasLeg, subgraph_factors=[3,], type=g2p.type(), operator=Graphs.Prod())
    gp = Graph([g3p,]; topology=g3p.topology, vertices=g3p.vertices, external=g3p.external,
        hasLeg=g3p.hasLeg, subgraph_factors=[2,], type=g3p.type(), operator=Graphs.Prod())
    @testset "merge Prod chain subfactors" begin
        # g ↦ 30*(*(*g1))
        g_merged = merge_prodchain_subfactors(g)
        @test g_merged.subgraph_factors == [30,]
        @test all(isfactorless(node) for node in PreOrderDFS(eldest(g_merged)))
        # in-place form
        gc = deepcopy(g)
        merge_prodchain_subfactors!(gc)
        @test isequiv(gc, g_merged, :id)
        # gp ↦ 6*(*(g1 + 5*g1))
        gp_merged = merge_prodchain_subfactors(gp)
        @test gp_merged.subgraph_factors == [6,]
        @test isfactorless(eldest(gp)) == false
        @test isfactorless(eldest(gp_merged))
        @test isequiv(eldest(eldest(gp_merged)), g2p, :id)
    end
    @testset "in-place product" begin
        # g ↦ 30*g1
        g_inplace = inplace_prod(g)
        @test isequiv(g_inplace, 30 * g1, :id)
        # in-place form
        inplace_prod!(g)
        @test isequiv(g, 30 * g1, :id)
        # gp ↦ 6*(g1 + 5*g1)
        gp_inplace = inplace_prod(gp)
        @test isequiv(gp_inplace, 6 * g2p, :id)
    end
    @testset "merge prefactors" begin
        g1 = propagator(𝑓⁺(1)𝑓⁻(2))
        h1 = linear_combination(g1, g1, 1, 2)
        @test h1.subgraph_factors == [1, 2]
        h2 = merge_prefactors(h1)
        @test h2.subgraph_factors == [3]
        @test length(h2.subgraphs) == 1
        @test isequiv(h2.subgraphs[1], g1, :id)
        g2 = propagator(𝑓⁺(1)𝑓⁻(2), factor=2)
        h3 = linear_combination(g1, g2, 1, 2)
        h4 = merge_prefactors(h3)
        @test isequiv(h3, h4, :id)
        h5 = linear_combination([g1, g2, g2, g1], [3, 5, 7, 9])
        h6 = merge_prefactors(h5)
        @test length(h6.subgraphs) == 2
        @test h6.subgraphs == [g1, g2]
        @test h6.subgraph_factors == [12, 12]
        g3 = 2 * g1
        h7 = linear_combination([g1, g3, g3, g1], [3, 5, 7, 9])
        h8 = merge_prefactors(h7)
        @test_broken length(h8.subgraphs) == 1
        @test_broken h8.subgraphs == [g1]
        @test_broken h8.subgraph_factors == [36]
    end
end

@testset verbose = true "Evaluation" begin
    using FeynmanDiagram.ComputationalGraphs:
        eval!
    g1 = propagator(𝑓⁻(1)𝑓⁺(2))
    g2 = propagator(𝑓⁻(1)𝑓⁺(2), factor=2)
    g3 = 2 * (3 * g1 + 5 * g2)
    g4 = g1 + 2 * (3 * g1 + 5 * g2)
    g5 = g4 * g3
    @testset "Eval" begin
        @test eval!(g3) == 26
        @test eval!(g4) == 27
        @test eval!(g5) == 27 * 26
    end
end

@testset verbose = true "Auto Differentiation" begin
    using FeynmanDiagram.ComputationalGraphs:
        eval!, frontAD, backAD, node_derivative, forwardAD_root
    g1 = propagator(𝑓⁻(1)𝑓⁺(2))
    g2 = propagator(𝑓⁻(3)𝑓⁺(4))
    g3 = propagator(𝑓⁻(5)𝑓⁺(6), factor=2.0)
    print("type:$(g2.type)\n")
    G3 = g1
    G4 = 4 * g1 * g1
    G5 = 4 * (2 * G3 + 3 * G4)
    G6 = (2 * g1 + 3 * g2) * (4 * g1 + g3)
    G7 = (3 * g1 + 4 * g2 + 5 * g3) * 3 * g1

    @testset "node_derivative" begin
        F1 = g1 * g1
        F2 = (3 * g1) * (4 * g1)
        F3 = (2 * g1 * g2) * (3 * g1)
        F4 = (2 * g1 + 3 * g2) + g1
        @test eval!(node_derivative(F1, g1)) == 2
        @test eval!(node_derivative(F2, g1)) == 24
        @test eval!(node_derivative(F1, g2)) == nothing
        @test eval!(node_derivative(F3, g1)) == 6 #The derivative is local, and only considers the children at root 
        print(node_derivative(F4, g1), "\n")
        @test eval!(node_derivative(F4, g1)) == 1
    end
    @testset "Eval" begin
        # Current test assign all green's function equal to 1 for simplicity.
        # print(eval!(frontAD(G5, g1.id)),"\n")
        # print(eval!(frontAD(G3, g1.id)),"\n")
        # print(eval!(frontAD(G3, g2.id)),"\n")
        # print(eval!(frontAD(G6, g1.id)),"\n")
        # print(eval!(frontAD(frontAD(G6, g1.id), g2.id)),"\n")
        # print(eval!(frontAD(frontAD(G6, g1.id), g3.id)),"\n")
        # gs = Compilers.to_julia_str([frontAD(G5, g1.id),], name="eval_graph!")
        # println(gs,"\n")
        @test eval!(frontAD(G3, g1.id)) == 1
        @test eval!(frontAD(G4, g1.id)) == 8
        @test eval!(frontAD(G5, g1.id)) == 104
        @test eval!(frontAD(G6, g1.id)) == 32
        @test eval!(frontAD(G6, g3.id)) == 5
        @test eval!(frontAD(frontAD(G6, g1.id), g2.id)) == 12
        backAD(G5, true)
        # for (i, G) in enumerate([G5,])#[G3, G4, G5, G6, G7])
        #     back_deriv = backAD(G)
        #     for (key, value) in back_deriv
        #         gs = Compilers.to_julia_str([value,], name="eval_graph!")
        #         println("id:$(key)", gs, "\n")
        #         print("Parent:$(i+2)  id:$(key)  $(eval!(value))   $(eval!(frontAD(G,key)))\n")
        #     end
        # end
    end
    @testset "forwardAD_root" begin
        F3 = g1 + g2
        F2 = linear_combination([g1, g3, F3], [2, 1, 3])
        F1 = Graph([g1, F2, F3], operator=Graphs.Prod(), subgraph_factors=[3.0, 1.0, 1.0])

        dual = forwardAD_root(F1)  # auto-differentation!
        @test dual[F3.id].subgraphs == [dual[g1.id], dual[g2.id]]
        @test dual[F2.id].subgraphs == [dual[g1.id], dual[g3.id], dual[F3.id]]

        leafmap = Dict{Int,Int}()
        leafmap[g1.id], leafmap[g2.id], leafmap[g3.id] = 1, 2, 3
        leafmap[dual[g1.id].id] = 4
        leafmap[dual[g2.id].id] = 5
        leafmap[dual[g3.id].id] = 6
        leaf = [1.0, 1.0, 1.0, 1.0, 0.0, 0.0]   # d F1 / d g1
        @test eval!(dual[F1.id], leafmap, leaf) == 120.0
        @test eval!(dual[F2.id], leafmap, leaf) == 5.0
        @test eval!(dual[F3.id], leafmap, leaf) == 1.0

        leaf = [5.0, -1.0, 2.0, 0.0, 1.0, 0.0]  # d F1 / d g2
        @test eval!(dual[F1.id], leafmap, leaf) == 570.0
        @test eval!(dual[F2.id], leafmap, leaf) == 3.0
        @test eval!(dual[F3.id], leafmap, leaf) == 1.0

        leaf = [5.0, -1.0, 2.0, 0.0, 0.0, 1.0]  # d F1 / d g3
        @test eval!(dual[F1.id], leafmap, leaf) == 60.0
        @test eval!(dual[F2.id], leafmap, leaf) == 1.0
        @test eval!(dual[F3.id], leafmap, leaf) == 0.0

        F0 = F1 * F3
        dual1 = forwardAD_root(F0)
        leafmap[dual1[g1.id].id] = 4
        leafmap[dual1[g2.id].id] = 5
        leafmap[dual1[g3.id].id] = 6

        leaf = [1.0, 1.0, 1.0, 1.0, 0.0, 0.0]
        @test eval!(dual1[F0.id], leafmap, leaf) == 300.0
        leaf = [5.0, -1.0, 2.0, 0.0, 1.0, 0.0]
        @test eval!(dual1[F0.id], leafmap, leaf) == 3840.0
        leaf = [5.0, -1.0, 2.0, 0.0, 0.0, 1.0]
        @test eval!(dual1[F0.id], leafmap, leaf) == 240.0
        @test isequiv(dual[F1.id], dual1[F1.id], :id, :weight, :vertices)

        F0_r1 = F1 + F3
        dual = forwardAD_root([F0, F0_r1])
        leafmap[dual[g1.id].id] = 4
        leafmap[dual[g2.id].id] = 5
        leafmap[dual[g3.id].id] = 6
        @test eval!(dual[F0.id], leafmap, leaf) == 240.0
        @test eval!(dual[F0_r1.id], leafmap, leaf) == 60.0
        @test isequiv(dual[F0.id], dual1[F0.id], :id, :weight)
        @test isequiv(dual[F1.id], dual1[F1.id], :id, :weight)
    end
end

@testset verbose = true "Tree properties" begin
    using FeynmanDiagram.ComputationalGraphs:
        haschildren, onechild, isleaf, isbranch, ischain, isfactorless, eldest, count_operation
    # Leaves: gᵢ
    g1 = propagator(𝑓⁻(1)𝑓⁺(2))
    g2 = propagator(𝑓⁻(1)𝑓⁺(2), factor=2)
    # Branches: Ⓧ --- gᵢ
    g3 = 1 * g1
    g4 = 1 * g2
    g5 = 2 * g1
    # Chains: Ⓧ --- Ⓧ --- gᵢ (simplified by default)
    g6 = Graph([g5,]; vertices=g5.vertices, topology=g5.topology, external=g5.external,
        hasLeg=g5.hasLeg, subgraph_factors=[1,], type=g5.type(), operator=Graphs.Prod())
    g7 = Graph([g3,]; vertices=g3.vertices, topology=g3.topology, external=g3.external,
        hasLeg=g3.hasLeg, subgraph_factors=[2,], type=g3.type(), operator=Graphs.Prod())
    # General trees
    g8 = 2 * (3 * g1 + 5 * g2)
    g9 = g1 + 2 * (3 * g1 + 5 * g2)
    g10 = g1 * g2 + g8 * g9
    glist = [g1, g2, g8, g9, g10]

    @testset "Leaves" begin
        @test haschildren(g1) == false
        @test onechild(g1) == false
        @test isleaf(g1)
        @test isbranch(g1) == false
        @test ischain(g1)
        @test isfactorless(g1)
        @test isfactorless(g2) == false
        @test_throws AssertionError eldest(g1)
        @test count_operation(g1) == [0, 0]
        @test count_operation(g2) == [0, 0]
    end
    @testset "Branches" begin
        @test haschildren(g3)
        @test onechild(g3)
        @test isleaf(g3) == false
        @test isbranch(g3)
        @test ischain(g3)
        @test isfactorless(g3)
        @test isfactorless(g4)
        @test isfactorless(g5) == false
        @test isleaf(eldest(g3))
    end
    @testset "Chains" begin
        @test haschildren(g6)
        @test onechild(g6)
        @test isleaf(g6) == false
        @test isbranch(g6) == false
        @test ischain(g6)
        @test isfactorless(g6)
        @test isfactorless(g7) == false
        @test isbranch(eldest(g6))
    end
    @testset "General" begin
        @test haschildren(g8)
        @test onechild(g8)
        @test isleaf(g8) == false
        @test isbranch(g8) == false
        @test ischain(g8) == false
        @test isfactorless(g8) == false
        @test onechild(eldest(g8)) == false
        @test count_operation(g8) == [1, 0]
        @test count_operation(g9) == [2, 0]
        @test count_operation(g10) == [4, 2]
    end
    @testset "Iteration" begin
        count_pre = sum(1 for node in PreOrderDFS(g9))
        count_post = sum(1 for node in PostOrderDFS(g9))
        @test count_pre == 8
        @test count_post == 8
    end
end

@testset "graph vector" begin
    p1 = propagator(𝑓⁺(1)𝑓⁻(2))
    p2 = propagator(𝑓⁺(1)𝑓⁻(3))
    p3 = propagator(𝑓⁺(2)𝑓⁻(3))

    gv = [p1, p2, p3]

    g1 = Graphs.group(gv, [2,])
    @test Set(g1[[𝑓⁺(1),]]) == Set([p1, p2])
    @test Set(g1[[𝑓⁺(2),]]) == Set([p3,])

    g2 = Graphs.group(gv, [1,])
    @test Set(g2[[𝑓⁻(2),]]) == Set([p1,])
    @test Set(g2[[𝑓⁻(3),]]) == Set([p2, p3])

    g3 = Graphs.group(gv, [2, 1])
    @test Set(g3[[𝑓⁺(1), 𝑓⁻(2)]]) == Set([p1,])
    @test Set(g3[[𝑓⁺(1), 𝑓⁻(3)]]) == Set([p2,])
    @test Set(g3[[𝑓⁺(2), 𝑓⁻(3)]]) == Set([p3,])
end

@testset "propagator" begin
    g1 = propagator(𝑓⁺(1)𝑓⁻(2))
    @test g1.factor == -1
    @test g1.external == [2, 1]
    @test vertices(g1) == [𝑓⁺(1), 𝑓⁻(2)]
    @test external(g1) == 𝑓⁻(2)𝑓⁺(1)
    @test external_labels(g1) == [2, 1]
end

@testset "interaction" begin
    ops = 𝑓⁺(1)𝑓⁻(2)𝑓⁻(3)𝑓⁺(4)𝜙(5)
    g1 = interaction(ops)
    @test g1.factor == 1
    @test g1.external == [1, 2, 3, 4, 5]
    @test vertices(g1) == [ops]
    @test external(g1) == ops
    @test external_labels(g1) == [1, 2, 3, 4, 5]

    g2 = interaction(ops, reorder=normal_order)
    @test g2.factor == -1
    @test vertices(g2) == [ops]
    @test external(g2) == 𝑓⁺(1)𝑓⁺(4)𝜙(5)𝑓⁻(3)𝑓⁻(2)
    @test external_labels(g2) == [1, 4, 5, 3, 2]
end

@testset verbose = true "feynman_diagram" begin
    @testset "Phi4" begin
        # phi theory 
        V1 = [interaction(𝜙(1)𝜙(2)𝜙(3)𝜙(4))]
        g1 = feynman_diagram(V1, [[1, 2], [3, 4]])    #vacuum diagram
        @test vertices(g1) == [𝜙(1)𝜙(2)𝜙(3)𝜙(4)]
        @test isempty(external(g1))
        @test g1.subgraph_factors == [1, 1, 1]
    end
    @testset "Complex scalar field" begin
        #complex scalar field
        V2 = [𝑏⁺(1), 𝑏⁺(2)𝑏⁺(3)𝑏⁻(4)𝑏⁻(5), 𝑏⁺(6)𝑏⁺(7)𝑏⁻(8)𝑏⁻(9), 𝑏⁻(10)]
        g2V = [external_vertex(V2[1]), interaction(V2[2]), interaction(V2[3]), external_vertex(V2[4])]
        g2 = feynman_diagram(g2V, [[1, 5], [2, 8], [3, 9], [4, 6], [7, 10]])    # Green2
        @test vertices(g2) == V2
        @test external(g2) == 𝑏⁺(1)𝑏⁻(10)
        @test g2.subgraph_factors == ones(Int, 9)
    end
    @testset "Yukawa interaction" begin
        # Yukawa 
        V3 = [𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6)]
        g3 = feynman_diagram(interaction.(V3), [[1, 5], [2, 4], [3, 6]])  #vacuum diagram
        @test vertices(g3) == V3
        @test isempty(external(g3))
        @test g3.factor == 1
        @test g3.subgraph_factors == ones(Int, 5)
        @test g3.subgraphs[3].factor == -1
        @test g3.subgraphs[3].vertices == [𝑓⁺(1), 𝑓⁻(5)]
        @test external(g3.subgraphs[3]) == 𝑓⁻(5)𝑓⁺(1)

        V4 = [𝑓⁺(1)𝑓⁻(2), 𝑓⁺(3)𝑓⁻(4)𝜙(5), 𝑓⁺(6)𝑓⁻(7)𝜙(8), 𝑓⁺(9)𝑓⁻(10)]
        g4 = feynman_diagram([external_vertex(V4[1]), interaction.(V4[2:3])..., external_vertex(V4[4])],
            [[1, 4], [2, 6], [3, 10], [5, 8], [7, 9]]) # polarization diagram
        @test g4.factor == -1
        @test g4.subgraph_factors == ones(Int, 9)
        @test vertices(g4) == V4
        @test external(g4) == 𝑓⁺(1)𝑓⁻(2)𝑓⁺(9)𝑓⁻(10)

        V5 = [𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6), 𝑓⁺(7)𝑓⁻(8)𝜙(9)]
        g5 = feynman_diagram(interaction.(V5), [[1, 5], [3, 9], [4, 8]])  # vertex function
        @test g5.factor == -1
        @test g5.subgraph_factors == ones(Int, 6)
        @test vertices(g5) == V5
        @test external(g5) == 𝑓⁻(2)𝜙(6)𝑓⁺(7)
        g5p = feynman_diagram(interaction.(V5), [[1, 5], [3, 9], [4, 8]], [3, 1, 2])
        @test g5.factor ≈ -g5p.factor    # reorder of external fake legs will not change the sign.
        @test g5p.subgraph_factors == ones(Int, 6)
        @test external(g5p) == 𝑓⁺(7)𝑓⁻(2)𝜙(6)

        V6 = [𝑓⁻(8), 𝑓⁺(1), 𝑓⁺(2)𝑓⁻(3)𝜙(4), 𝑓⁺(5)𝑓⁻(6)𝜙(7)]
        g6 = feynman_diagram([external_vertex.(V6[1:2]); interaction.(V6[3:4])], [[2, 4], [3, 7], [5, 8], [6, 1]])    # fermionic Green2
        @test g6.factor == -1
        @test g6.subgraph_factors == ones(Int, 8)
        @test external(g6) == 𝑓⁻(8)𝑓⁺(1)

        V7 = [𝑓⁻(7), 𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6)]
        g7 = feynman_diagram([external_vertex(V7[1]), interaction.(V7[2:3])...], [[2, 6], [4, 7], [5, 1]])     # sigma*G
        @test g7.factor == 1
        @test external(g7) == 𝑓⁻(7)𝑓⁻(2)

        V8 = [𝑓⁺(2), 𝑓⁻(12), 𝑓⁺(3)𝑓⁻(4)𝜙(5), 𝑓⁺(6)𝑓⁻(7)𝜙(8), 𝑓⁺(9)𝑓⁻(10)𝜙(11), 𝑓⁺(13)𝑓⁻(14)𝜙(15)]
        g8 = feynman_diagram([external_vertex.(V8[1:2]); interaction.(V8[3:end])], [[1, 4], [3, 7], [5, 14], [6, 13], [8, 11], [9, 2]])
        @test g8.factor == -1
        @test vertices(g8) == V8
        @test external(g8) == 𝑓⁺(2)𝑓⁻(12)𝑓⁻(10)𝑓⁺(13)

        g8p = feynman_diagram([external_vertex.(V8[1:2]); interaction.(V8[3:end])],
            [[1, 4], [3, 7], [5, 14], [6, 13], [8, 11], [9, 2]], [2, 1])
        @test g8p.factor == 1
        @test external(g8p) == 𝑓⁺(2)𝑓⁻(12)𝑓⁺(13)𝑓⁻(10)
    end
    @testset "f+f+f-f- interaction" begin
        V1 = [𝑓⁺(3), 𝑓⁺(4), 𝑓⁺(5)𝑓⁺(6)𝑓⁻(7)𝑓⁻(8), 𝑓⁺(9)𝑓⁺(10)𝑓⁻(11)𝑓⁻(12)]
        g1 = feynman_diagram([external_vertex.(V1[1:2]); interaction.(V1[3:4])], [[1, 6], [2, 9], [4, 10], [5, 7]])
        g1p = feynman_diagram([external_vertex.(V1[2:-1:1]); interaction.(V1[3:4])],
            [[2, 6], [1, 9], [4, 10], [5, 7]], [2, 1])
        @test g1p.factor ≈ g1.factor
        @test external(g1) == 𝑓⁺(3)𝑓⁺(4)𝑓⁺(5)𝑓⁺(10)
        @test vertices(g1p) == [𝑓⁺(4), 𝑓⁺(3), 𝑓⁺(5)𝑓⁺(6)𝑓⁻(7)𝑓⁻(8), 𝑓⁺(9)𝑓⁺(10)𝑓⁻(11)𝑓⁻(12)]
        @test external(g1p) == 𝑓⁺(4)𝑓⁺(3)𝑓⁺(10)𝑓⁺(5)

        V2 = [𝑓⁺(2), 𝑓⁻(3), 𝑓⁺(4)𝑓⁺(5)𝑓⁻(6)𝑓⁻(7), 𝑓⁺(8)𝑓⁺(9)𝑓⁻(10)𝑓⁻(11)]
        g2 = feynman_diagram([external_vertex.(V2[1:2]); interaction.(V2[3:4])], [[1, 6], [2, 3], [4, 10], [5, 8]])
        @test g2.factor == -1
        @test external(g2) == 𝑓⁺(2)𝑓⁻(3)𝑓⁺(8)𝑓⁻(10)
        @test external_labels(g2) == [2, 3, 8, 10] # labels of external vertices    
    end
    @testset "Construct feynman diagram from sub-diagrams" begin
        V1 = [𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6)]
        g1 = feynman_diagram(interaction.(V1), [[3, 6]])
        V2 = [𝑓⁺(7)𝑓⁻(8)𝜙(9), 𝑓⁺(10)𝑓⁻(11)𝜙(12)]
        g2 = feynman_diagram(interaction.(V2), [[3, 6]])

        V3 = [𝑓⁻(13), 𝑓⁻(14), 𝑓⁺(15), 𝑓⁺(16)]
        g = feynman_diagram([g1, g2, external_vertex.(V3)...], [[1, 6], [2, 12], [3, 9], [4, 5], [7, 10], [8, 11]])

        @test vertices(g) == [𝑓⁺(1)𝑓⁻(2)𝑓⁺(4)𝑓⁻(5), 𝑓⁺(7)𝑓⁻(8)𝑓⁺(10)𝑓⁻(11), V3...]
        @test external(g) == reduce(*, V3)
    end
end

@testset verbose = true "Graph" begin
    V = [𝑓⁺(1)𝑓⁻(2), 𝑓⁺(5)𝑓⁺(6)𝑓⁻(7)𝑓⁻(8), 𝑓⁺(3)𝑓⁻(4)]
    g1 = Graph(V, external=[1, 3])
    g2 = g1 * 2
    @testset "Scalar multiplication" begin
        @test vertices(g2) == vertices(g1)
        println(external(g2))
        println(external(g1))
        @test external(g2) == external(g1)
        @test g2.subgraph_factors == [2]
        @test g2.operator == ComputationalGraphs.Prod
        g2 = 2g1
        @test vertices(g2) == vertices(g1)
        @test external(g2) == external(g1)
        @test g2.subgraph_factors == [2]
        @test g2.operator == ComputationalGraphs.Prod
    end
    @testset "Graph addition" begin
        g3 = g1 + g2
        @test vertices(g3) == vertices(g1)
        @test external(g3) == external(g1)
        @test g3.factor == 1
        @test g3.subgraphs == [g1, g2]
        @test g3.subgraph_factors == [1, 1]
        @test isempty(g3.subgraphs[1].subgraph_factors)
        @test g3.subgraphs[2].subgraph_factors == [2]
        @test g3.operator == ComputationalGraphs.Sum
    end
    @testset "Graph subtraction" begin
        g4 = g1 - g2
        @test vertices(g4) == vertices(g1)
        @test external(g4) == external(g1)
        @test g4.factor == 1
        @test g4.subgraphs == [g1, g2]
        @test g4.subgraph_factors == [1, -1]
        @test isempty(g4.subgraphs[1].subgraph_factors)
        @test g4.subgraphs[2].subgraph_factors == [2]
        @test g4.subgraphs[2].subgraphs[1].factor == 1
        @test g4.operator == ComputationalGraphs.Sum
    end
    @testset "Linear combinations" begin
        # Binary form
        g5 = 3g1 + 5g2
        g5lc = ComputationalGraphs.linear_combination(g1, g2, 3, 5)
        @test g5.subgraph_factors == [1, 1]
        @test [g.subgraph_factors[1] for g in g5.subgraphs] == [3, 10]
        @test g5lc.subgraphs == [g1, g2]
        @test g5lc.subgraph_factors == [3, 5]
        # Requires optimization merge_prefactors on g5
        @test_broken isequiv(g5, g5lc, :id)
        # Vector form
        g6lc = ComputationalGraphs.linear_combination([g1, g2, g5, g2, g1], [3, 5, 7, 9, 11])
        @test g6lc.subgraphs == [g1, g2, g5, g2, g1]
        @test g6lc.subgraph_factors == [3, 5, 7, 9, 11]
    end
    @testset "Multiplicative chains" begin
        g6 = 7 * (5 * (3 * (2 * g1)))
        @test g6.subgraph_factors == [210]
        @test isempty(g6.subgraphs[1].subgraphs)
        @test isempty(g6.subgraphs[1].subgraph_factors)
        g7 = (((g1 * 2) * 3) * 5) * 7
        @test g7.subgraph_factors == [210]
        @test isempty(g7.subgraphs[1].subgraphs)
        @test isempty(g7.subgraphs[1].subgraph_factors)
    end
end

@testset "propagator" begin
    # g1 = propagator(𝑓⁺(1)𝑓⁻(2))
    g1 = propagator([𝑓⁺(1), 𝑓⁻(2)])
    @test g1.factor == 1
    @test g1.external == [1, 2]
    @test vertices(g1) == [𝑓⁺(1), 𝑓⁻(2)]
    @test OperatorProduct(external_legs(g1)) == OperatorProduct(external(g1)) == 𝑓⁺(1)𝑓⁻(2)
    standardize_order!(g1)
    @test g1.factor == -1
    @test g1.external == [1, 2]
    @test OperatorProduct(external_legs(g1)) == OperatorProduct(external(g1)) == 𝑓⁻(2)𝑓⁺(1)
    # @test vertices(g1) == [𝑓⁻(2)𝑓⁺(1)]

    g2 = propagator([𝑓⁺(1), 𝑓⁻(2), 𝑏⁺(1), 𝜙(1), 𝑓⁺(3), 𝑓⁻(1), 𝑓(1), 𝑏⁻(1), 𝜙(1)])
    @test OperatorProduct(vertices(g2)) == OperatorProduct(external_legs(g2)) == OperatorProduct(external(g2)) == 𝑓⁺(1)𝑓⁻(2)𝑏⁺(1)𝜙(1)𝑓⁺(3)𝑓⁻(1)𝑓(1)𝑏⁻(1)𝜙(1)
    standardize_order!(g2)
    @test g2.factor == -1
    @test OperatorProduct(vertices(g2)) == OperatorProduct(external_legs(g2)) == OperatorProduct(external(g2)) == 𝑓⁻(1)𝑏⁻(1)𝜙(1)𝑓⁻(2)𝑓(1)𝑓⁺(3)𝜙(1)𝑏⁺(1)𝑓⁺(1)
end

@testset verbose = true "feynman_diagram" begin
    @testset "Phi4" begin
        # phi theory 
        V1 = [𝜙(1)𝜙(1)𝜙(2)𝜙(2),]
        g1 = feynman_diagram(V1, [[1, 2], [3, 4]])    #vacuum diagram
        # g1 = feynman_diagram(V1, [1, 1, 2, 2])
        @test vertices(g1) == V1
        @test isempty(external(g1))
        @test g1.subgraph_factors == [1, 1]
    end
    @testset "Complex scalar field" begin
        #complex scalar field
        V2 = [𝑏⁺(1), 𝑏⁺(2)𝑏⁺(3)𝑏⁻(4)𝑏⁻(5), 𝑏⁺(6)𝑏⁺(7)𝑏⁻(8)𝑏⁻(9), 𝑏⁻(10)]
        # g2 = feynman_diagram(V2, [1, 2, 3, 4, 1, 4, 5, 2, 3, 5]; external=[1, 10])
        g2 = feynman_diagram(V2, [[1, 5], [2, 8], [3, 9], [4, 6], [7, 10]]; external=[1, 10])    # Green2
        @test vertices(g2) == V2
        @test external(g2) == OperatorProduct(V2)[[1, 10]]
        @test g2.subgraph_factors == [1, 1, 1, 1, 1]
    end
    @testset "Yukawa interaction" begin
        # Yukawa 
        V3 = [𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6)]
        # g3 = feynman_diagram(V3, [1, 2, 3, 2, 1, 3])
        g3 = feynman_diagram(V3, [[1, 5], [2, 4], [3, 6]])  #vacuum diagram
        @test vertices(g3) == V3
        @test isempty(external(g3))
        @test g3.factor == 1
        @test g3.subgraph_factors == [1, 1, 1]
        # @test internal_vertices(g3) == V3
        @test g3.subgraphs[1].factor == 1
        @test g3.subgraphs[1].vertices == [𝑓⁺(1), 𝑓⁻(5)]
        @test g3.subgraphs[1].factor == 1
        @test OperatorProduct(external(g3.subgraphs[1])) == 𝑓⁺(1)𝑓⁻(5)
        standardize_order!(g3)
        @test g3.subgraphs[1].factor == -1
        @test OperatorProduct(external(g3.subgraphs[1])) == 𝑓⁻(5)𝑓⁺(1)

        V4 = [𝜙(13, true), 𝜙(14, true), 𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6), 𝑓⁺(7)𝑓⁻(8)𝜙(9), 𝑓⁺(10)𝑓⁻(11)𝜙(12),]
        g4 = feynman_diagram(V4, [[3, 10], [4, 12], [6, 13], [7, 9], [11, 14], [5, 1], [8, 2]], external=[5, 8]) # polarization diagram
        @test g4.factor == -1
        @test g4.subgraph_factors == [1, 1, 1, 1, 1]
        @test vertices(g4) == V4
        @test external(g4) == OperatorProduct(V4)[[5, 8]]
        @test isempty(real_extV(g4))
        @test fake_extV(g4) == OperatorProduct(V4)[[5, 8]]
        standardize_order!(g4)
        @test external(g4) == OperatorProduct(V4)[[5, 8]]
        # @test internal_vertices(g4) == V4[3:4]

        V5 = [𝑓⁻(1, true), 𝑓⁺(11, true), 𝜙(12, true), 𝑓⁺(2)𝑓⁻(3)𝜙(4), 𝑓⁺(5)𝑓⁻(6)𝜙(7), 𝑓⁺(8)𝑓⁻(9)𝜙(10)]
        g5 = feynman_diagram(V5, [[5, 7], [6, 12], [8, 10], [1, 4], [3, 9], [11, 2]], external=[4, 9, 11])  # vertex function
        @test g5.factor == 1
        @test g5.subgraph_factors == [1, 1, 1]
        @test vertices(g5) == V5
        @test external(g5) == OperatorProduct(V5)[[4, 9, 11]]
        @test fake_extV(g5) == OperatorProduct(V5)[[4, 9, 11]]
        @test external_legs(g5) == OperatorProduct(V5)[1:3]
        # @test isempty(internal_vertices(g5))
        g5s = deepcopy(g5)
        standardize_order!(g5)
        @test g5.factor == -1
        @test external(g5) == OperatorProduct(V5)[[4, 9, 11]]
        @test external_legs(g5) == OperatorProduct(V5)[[2, 3, 1]]
        # @test g5s == g5

        V5p = [𝑓⁺(11, true), 𝑓⁻(1, true), 𝜙(12, true), 𝑓⁺(2)𝑓⁻(3)𝜙(4), 𝑓⁺(5)𝑓⁻(6)𝜙(7), 𝑓⁺(8)𝑓⁻(9)𝜙(10)]
        g5p = feynman_diagram(V5p, [[5, 7], [6, 12], [8, 10], [2, 4], [3, 9], [11, 1]], external=[11, 9, 4])
        @test g5.factor ≈ g5p.factor    # reorder of external fake legs will not change the sign.
        @test g5p.subgraph_factors == [1, 1, 1]
        standardize_order!(g5p)
        @test external(g5p) == OperatorProduct(V5)[[11, 9, 4]]
        @test g5p.factor ≈ g5.factor

        V6 = [𝑓⁻(8), 𝑓⁺(1), 𝑓⁺(2)𝑓⁻(3)𝜙(4), 𝑓⁺(5)𝑓⁻(6)𝜙(7)]
        g6 = feynman_diagram(V6, [[2, 4], [3, 7], [5, 8], [6, 1]], external=[1, 2])    # fermionic Green2
        @test g6.factor == -1
        @test g6.subgraph_factors == [1, 1, 1, 1]
        @test external(g6) == OperatorProduct(V6)[1:2]
        standardize_order!(g6)
        @test g6.factor == 1
        @test external(g6) == OperatorProduct(V6)[[2, 1]]

        V7 = [𝑓⁻(7), 𝑓⁺(8, true), 𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6)]
        g7 = feynman_diagram(V7, [[3, 7], [5, 8], [6, 1], [4, 2]], external=[1, 4])     # sigma*G
        @test g7.factor == 1
        @test real_extV(g7) == OperatorProduct(V7)[[1]]
        @test fake_extV(g7) == OperatorProduct(V7)[[4]]

        V8 = [𝑓⁻(1, true), 𝑓⁺(2), 𝑓⁻(12), 𝑓⁺(16, true), 𝑓⁺(3)𝑓⁻(4)𝜙(5), 𝑓⁺(6)𝑓⁻(7)𝜙(8), 𝑓⁺(9)𝑓⁻(10)𝜙(11), 𝑓⁺(13)𝑓⁻(14)𝜙(15)]
        g8 = feynman_diagram(V8, [[2, 6], [5, 9], [7, 16], [8, 15], [10, 13], [11, 3], [12, 4], [14, 1]], external=[2, 12, 3, 14])
        @test g8.factor == -1
        @test real_extV(g8) == OperatorProduct(V8)[[2, 3]]
        @test fake_extV(g8) == OperatorProduct(V8)[[12, 14]]
        V8p = [𝑓⁺(2), 𝑓⁻(1, true), 𝑓⁻(12), 𝑓⁺(16, true), 𝑓⁺(3)𝑓⁻(4)𝜙(5), 𝑓⁺(6)𝑓⁻(7)𝜙(8), 𝑓⁺(9)𝑓⁻(10)𝜙(11), 𝑓⁺(13)𝑓⁻(14)𝜙(15)]
        g8p = feynman_diagram(V8p, [[1, 6], [5, 9], [7, 16], [8, 15], [10, 13], [11, 3], [12, 4], [14, 2]], external=[12, 1, 3, 14])
        @test g8p.factor == 1
    end
    @testset "f+f+f-f- interaction" begin
        V1 = [𝑓⁻(1, true), 𝑓⁻(2, true), 𝑓⁺(3), 𝑓⁺(4), 𝑓⁺(5)𝑓⁺(6)𝑓⁻(7)𝑓⁻(8), 𝑓⁺(9)𝑓⁺(10)𝑓⁻(11)𝑓⁻(12)]
        g1 = feynman_diagram(V1, [[1, 5], [2, 10], [3, 8], [4, 11], [6, 12], [7, 9]], external=[3, 4, 5, 10])
        g1p = feynman_diagram(V1, [[1, 10], [2, 5], [3, 8], [4, 11], [6, 12], [7, 9]], external=[3, 4, 5, 10])
        @test g1p.factor ≈ -g1.factor
        @test real_extV(g1) == OperatorProduct(V1)[[3, 4]]
        @test fake_extV(g1) == OperatorProduct(V1)[[5, 10]]

        V2 = [𝑓⁻(1, true), 𝑓⁺(12, true), 𝑓⁺(2), 𝑓⁻(3), 𝑓⁺(4)𝑓⁺(5)𝑓⁻(6)𝑓⁻(7), 𝑓⁺(8)𝑓⁺(9)𝑓⁻(10)𝑓⁻(11)]
        g2 = feynman_diagram(V2, [[1, 9], [3, 8], [4, 5], [6, 12], [7, 10], [11, 2]], external=[3, 4, 9, 11])
        @test g2.factor == -1
        @test external_legs(g2) == OperatorProduct(V2)[1:4]
        @test real_extV(g2) == OperatorProduct(V2)[[3, 4]]
        @test fake_extV(g2) == OperatorProduct(V2)[[9, 11]]
        standardize_order!(g2)
        @test external_legs(g2) == OperatorProduct(V2)[[2, 3, 4, 1]]
    end
    @testset "Multi-operator contractions" begin
        # multi-operator (>2) contractions
        Vm = [𝑓(1, true), 𝑓⁺(2)𝑓⁻(3)𝑏⁺(4), 𝜙(5)𝑓⁺(6)𝑓⁻(7), 𝑓(8)𝑏⁻(9)𝜙(10)]
        gm = feynman_diagram(Vm, [[2, 3, 4, 9], [5, 6, 7, 10], [8, 1]], external=[8])
        @test vertices(gm) == Vm
        @test gm.subgraph_factors == [1, 1]
        @test gm.subgraphs[1].vertices == [𝑓⁺(2), 𝑓⁻(3), 𝑏⁺(4), 𝑏⁻(9)]
        @test gm.subgraphs[2].vertices == [𝜙(5), 𝑓⁺(6), 𝑓⁻(7), 𝜙(10)]
        @test OperatorProduct(external(gm.subgraphs[1])) == 𝑓⁺(2)𝑓⁻(3)𝑏⁺(4)𝑏⁻(9)
        @test OperatorProduct(external(gm.subgraphs[2])) == 𝜙(5)𝑓⁺(6)𝑓⁻(7)𝜙(10)
        @test external_legs(gm) == OperatorProduct(Vm)[[1]]
        @test external(gm) == fake_extV(gm) == OperatorProduct(Vm)[[8]]
        standardize_order!(gm)
        @test gm.subgraphs[1].factor == -1
        @test OperatorProduct(external(gm.subgraphs[1])) == 𝑓⁻(3)𝑏⁻(9)𝑏⁺(4)𝑓⁺(2)
        @test gm.subgraphs[2].factor == -1
        @test OperatorProduct(external(gm.subgraphs[2])) == 𝜙(5)𝑓⁻(7)𝜙(10)𝑓⁺(6)

        ggm = deepcopy(gm)
        ggm.id = 1000
        @test isequiv(gm, ggm, :id)
    end
end

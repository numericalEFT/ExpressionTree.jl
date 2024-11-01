using FeynmanDiagram: ComputationalGraphs as Graphs

# 𝓞 represents a non-trivial unary operation
struct O <: Graphs.AbstractOperator end

# 𝓞1, 𝓞2, and 𝓞3 represent trivial unary operations
struct O1 <: Graphs.AbstractOperator end
struct O2 <: Graphs.AbstractOperator end
struct O3 <: Graphs.AbstractOperator end
Graphs.unary_istrivial(::Type{O}) where {O<:Union{O1,O2,O3}} = true

@testset verbose = true "AbstractGraph interface" begin
    # Example of a custom graph type with additional type-stable node properties ("color")
    mutable struct ConcreteGraph <: Graphs.AbstractGraph
        id::Int
        name::String
        orders::Vector{Int}
        operator::DataType
        subgraphs::Vector{ConcreteGraph}
        subgraph_factors::Vector{Float64}
        weight::Float64
        color::String
        function ConcreteGraph(subgraphs=[]; name="", orders=zeros(Int, 0), operator=O(), subgraph_factors=[], weight=1.0, color="black")
            return new(Graphs.uid(), name, orders, typeof(operator), subgraphs, subgraph_factors, weight, color)
        end
    end

    # weight(g::AbstractGraph) is an abstract method
    @test isnothing(Graphs.weight(ConcreteGraph()))

    ### AbstractGraph interface for ConcreteGraph ###

    # Getters
    Graphs.id(g::ConcreteGraph) = g.id
    Graphs.name(g::ConcreteGraph) = g.name
    Graphs.orders(g::ConcreteGraph) = g.orders
    Graphs.operator(g::ConcreteGraph) = g.operator
    Graphs.weight(g::ConcreteGraph) = g.weight
    Graphs.properties(g::ConcreteGraph) = g.color
    Graphs.subgraph(g::ConcreteGraph, i=1) = g.subgraphs[i]
    Graphs.subgraphs(g::ConcreteGraph) = g.subgraphs
    Graphs.subgraph_factor(g::ConcreteGraph, i=1) = g.subgraph_factors[i]
    Graphs.subgraph_factors(g::ConcreteGraph) = g.subgraph_factors

    # Setters
    Graphs.set_name!(g::ConcreteGraph, name::AbstractString) = (g.name = name)
    Graphs.set_properties!(g::ConcreteGraph, color::AbstractString) = (g.color = color)
    Graphs.set_subgraph!(g::ConcreteGraph, subgraph::ConcreteGraph, i=1) = (g.subgraphs[i] = subgraph)
    Graphs.set_subgraphs!(g::ConcreteGraph, subgraphs::Vector{ConcreteGraph}) = (g.subgraphs = subgraphs)
    Graphs.set_subgraph_factor!(g::ConcreteGraph, subgraph_factor::Float64, i=1) = (g.subgraph_factors[i] = subgraph_factor)
    Graphs.set_subgraph_factors!(g::ConcreteGraph, subgraph_factors::AbstractVector) = (g.subgraph_factors = subgraph_factors)

    ###############################

    Graphs.uidreset()
    g1 = ConcreteGraph(; operator=O1(), color="red", name="g1")
    g2 = ConcreteGraph(; operator=O2(), color="green", name="g2")
    g3 = ConcreteGraph(; operator=O3(), color="blue", name="g3")
    g = ConcreteGraph([g1, g2, g3]; subgraph_factors=[2, 3, 5], operator=O())
    gp = ConcreteGraph([g1, g2, g3]; subgraph_factors=[2, 3, 5], operator=O())
    h = ConcreteGraph([g1, g2, g3]; name="h", subgraph_factors=[2, 3, 5], operator=O())

    # Base.:+(g1::AbstractGraph, g2::AbstractGraph) is an abstract method
    err = AssertionError()
    try
        g1 + g2
    catch err
    end
    @test err isa ErrorException
    @test err.msg == "Method not yet implemented for user-defined graph type ConcreteGraph."

    @testset "String representations" begin
        @test string(g1) == repr(g1) == "1: g1, red=1.0"
        @test string(g2) == repr(g2) == "2: g2, green=1.0"
        @test string(g3) == repr(g3) == "3: g3, blue=1.0"
        @test string(g) == repr(g) == "4: black=O(1,2,3)=1.0"
        @test string(gp) == repr(gp) == "5: black=O(1,2,3)=1.0"
        @test string(h) == repr(h) == "6: h, black=O(1,2,3)=1.0"
    end
    @testset "Traits" begin
        @test Graphs.unary_istrivial(g1) == true
        @test Graphs.unary_istrivial(g2) == true
        @test Graphs.unary_istrivial(g3) == true
        @test Graphs.unary_istrivial(g) == false
    end
    @testset "Getters" begin
        @test Graphs.id(g) == 4
        @test Graphs.name(g) == ""
        @test Graphs.orders(g) == zeros(Int, 0)
        @test Graphs.operator(g) == O
        @test Graphs.weight(g) == 1.0
        @test Graphs.properties(g) == "black"
        @test Graphs.subgraph(g) == g1
        @test Graphs.subgraph(g, 2) == g2
        @test Graphs.subgraphs(g) == [g1, g2, g3]
        @test Graphs.subgraphs(g, [2, 1]) == [g2, g1]  # default method
        @test Graphs.subgraph_factor(g) == 2.0
        @test Graphs.subgraph_factor(g, 2) == 3.0
        @test Graphs.subgraph_factors(g) == [2.0, 3.0, 5.0]
        @test Graphs.subgraph_factors(g, [2, 1]) == [3.0, 2.0]  # default method
    end
    @testset "Setters" begin
        Graphs.set_name!(g, "g")
        @test Graphs.name(g) == "g"
        Graphs.set_properties!(g, "white")
        @test Graphs.properties(g) == "white"
        @test string(g) == "4: g, white=O(1,2,3)=1.0"
        Graphs.set_properties!(g, "black")
        Graphs.set_subgraph!(g, g2, 1)
        @test Graphs.subgraph(g) == g2
        Graphs.set_subgraphs!(g, [g1, g2, g3])
        @test Graphs.subgraphs(g) == [g1, g2, g3]
        Graphs.set_subgraphs!(g, [g3, g1, g2], [3, 1, 2])  # default method
        @test Graphs.subgraphs(g) == [g1, g2, g3]
        Graphs.set_subgraph_factor!(g, 0.0, 1)
        @test Graphs.subgraph_factor(g) == 0.0
        Graphs.set_subgraph_factors!(g, [2.0, 3.0, 5.0])
        @test Graphs.subgraph_factors(g) == [2.0, 3.0, 5.0]
        Graphs.set_subgraph_factors!(g, [5.0, 2.0, 3.0], [3, 1, 2])  # default method
        @test Graphs.subgraph_factors(g) == [2.0, 3.0, 5.0]
    end
    @testset "Disconnect subgraphs" begin
        g_dc = deepcopy(g)
        Graphs.disconnect_subgraphs!(g_dc)
        @test isempty(Graphs.subgraphs(g_dc))
        @test isempty(Graphs.subgraph_factors(g_dc))
    end
    @testset "Equivalence" begin
        Graphs.set_name!(g, Graphs.name(gp))
        @test g == g
        @test g != gp
        @test Graphs.isequal(g, g)
        @test Graphs.isequal(g, gp) == false
        @test Graphs.isequiv(g, gp, :id)
        @test Graphs.isequiv(g, h, :id) == false
        @test Graphs.isequiv(g, h, :id, :name) == true
    end
end

@testset verbose = true "Graph" begin
    @testset verbose = true "Operations" begin
        g1 = Graph([])
        g2 = 2 * g1
        g2p = Graph([]; factor=2)
        @testset "Equivalence" begin
            g1_new_instance = Graph([])
            # Test equivalence modulo fields id/factor
            @test isequiv(g1, g1_new_instance) == false
            @test isequiv(g1, g1_new_instance, :id)
            @test isequiv(g1, eldest(g2p), :id)
            @test isequiv(g2, g2p, :id)
            # Test inequivalence when subgraph lengths are different
            t = g1 + g1
            @test isequiv(t, g1, :id) == false
        end
        @testset "Scalar multiplication" begin
            @test g2.subgraph_factors == [2]
            @test g2.operator == Graphs.Prod
            g3 = g1 * 2
            @test g3.subgraph_factors == [2]
            @test g3.operator == Graphs.Prod
        end
        @testset "Addition" begin
            g3 = g1 + g2
            @test g3.subgraphs == [g1]
            @test g3.subgraph_factors == [3]
            @test g3.operator == Graphs.Sum
        end
        @testset "Subtraction" begin
            g4 = g1 - g2
            @test g4.subgraphs == [g1]
            @test g4.subgraph_factors == [-1]
            @test g4.subgraphs[1] == g1
            @test g4.operator == Graphs.Sum
        end
        @testset "Linear combinations" begin
            # Binary form
            # NOTE: since g2 = 2 * g1, 5g2 ↦ 10g1 in final expressions
            g5 = 3g1 + 5g2
            g5lc = linear_combination(g1, g2, 3, 5)
            @test g5lc.subgraphs == [g1,]
            @test g5lc.subgraph_factors == [13,]
            @test isequiv(g5, g5lc, :id)
            # Vector form
            g6lc = linear_combination([g1, g2, g5, g2, g1], [3, 5, 7, 9, 11])
            @test g6lc.subgraphs == [g1]
            @test g6lc.subgraph_factors == [133]  # 3+5*2+7*13+9*2+11 
            # Test one-level merging of multiplicative chains
            g7lc = g1 + 2 * (3 * g1 + 5 * g2p)
            g7lc_expect = g1 + 2 * linear_combination([g1, g2p], [3, 5])
            @test isequiv(g7lc, g7lc_expect, :id)
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
    @testset verbose = true "Transformations" begin
        @testset "Replace subgraph" begin
            g1 = Graph([])
            g1p = Graph([]; operator=O())
            g2 = Graph([]; factor=2, operator=O())
            g3 = Graph([]; factor=3, operator=O())
            gsum = g2 + g3
            groot = g1 + gsum
            replace_subgraph!(groot, g1, g1p)
            @test isequiv(groot, g1p + Graph([g1p, g1p], subgraph_factors=[2, 3], operator=Graphs.Sum()), :id)
        end
        @testset "Prune trivial unary operations" begin
            g1 = Graph([])
            # +g1
            g2 = Graph([g1,]; operator=Graphs.Sum())
            # +(+g1)
            g3 = Graph([g2,]; operator=Graphs.Sum())
            # +2(+g1)
            g3p = Graph([g2,]; subgraph_factors=[2,], operator=Graphs.Sum())
            # +(+(+g1))
            g4 = Graph([g3,]; operator=Graphs.Sum())
            # +(+2(+g1))
            g4p = Graph([g3p,]; operator=Graphs.Sum())
            @test Graphs.unary_istrivial(Graphs.Prod)
            @test Graphs.unary_istrivial(Graphs.Sum)
            g5 = Graph([g1,]; operator=O())
            @test Graphs.unary_istrivial(O) == false
        end
        g1 = Graph([])
        g2 = Graph([g1,]; subgraph_factors=[5,], operator=Graphs.Prod())
        g3 = Graph([g2,]; subgraph_factors=[3,], operator=Graphs.Prod())
        # g: 2*(3*(5*g1))
        g = Graph([g3,]; subgraph_factors=[2,], operator=Graphs.Prod())
        g2p = Graph([g1, g2]; operator=Graphs.Sum())
        g3p = Graph([g2p,]; subgraph_factors=[3,], operator=Graphs.Prod())
        # gp: 2*(3*(g1 + 5*g1))
        gp = Graph([g3p,]; subgraph_factors=[2,], operator=Graphs.Prod())
        @testset "Merge prefactors" begin
            g1 = propagator(𝑓⁺(1)𝑓⁻(2))
            h1 = FeynmanGraph([g1, g1], drop_topology(g1.properties); subgraph_factors=[1, 2], operator=Graphs.Sum())
            h1_lc = linear_combination(g1, g1, 1, 2)
            @test h1_lc.subgraph_factors == [-3.0]
            h2 = merge_linear_combination(h1)
            @test h2.subgraph_factors == [3]
            @test length(h2.subgraphs) == 1
            @test h2.subgraphs[1] == g1
            h2_lc = FeynmanGraph([g1,], drop_topology(g1.properties); subgraph_factors=[3], operator=Graphs.Sum())
            @test isequiv(h2_lc, h2, :id)

            g2 = propagator(𝑓⁺(1)𝑓⁻(2), factor=2)
            h3 = linear_combination(g1, g2, 1, 2)
            g1s = propagator(𝑓⁺(1)𝑓⁻(2), factor=-1)
            @test isequiv(h3, FeynmanGraph([g1s, g1s], drop_topology(g1.properties); subgraph_factors=[-1, -4]), :id)
            h4 = merge_linear_combination(h3)
            @test isequiv(h4, FeynmanGraph([g1s], drop_topology(g1.properties); subgraph_factors=[-5]), :id)

            h5 = FeynmanGraph([g1, g2, g2, g1], drop_topology(g1.properties); subgraph_factors=[3, 5, 7, 9], operator=Graphs.Sum())
            h5_lc = linear_combination([g1, g2, g2, g1], [3, 5, 7, 9])
            h6 = merge_linear_combination(h5)
            @test length(h6.subgraphs) == 2
            @test h6.subgraphs == [g1, g2]
            @test h6.subgraph_factors == [12, 12]
            @test isequiv(h5_lc, FeynmanGraph([g1s, g1s], drop_topology(g1.properties); subgraph_factors=[-12, -24]), :id)
            @test isequiv(h6, FeynmanGraph([g1, g2], drop_topology(g1.properties); subgraph_factors=[12, 12]), :id)

            g3 = 2 * g1
            h7 = FeynmanGraph([g1, g1, g1, g1], drop_topology(g1.properties); subgraph_factors=[3, 5 * 2, 7 * 2, 9], operator=Graphs.Sum())
            h7_lc = linear_combination([g1, g3, g3, g1], [3, 5, 7, 9])
            h8 = merge_linear_combination(h7)
            @test length(h8.subgraphs) == 1
            @test h8.subgraphs == [g1]
            @test h8.subgraph_factors == [36]
            @test isequiv(h7_lc, FeynmanGraph([g1s,], drop_topology(g1.properties); subgraph_factors=[-36], operator=Graphs.Sum()), :id)
        end
        @testset "Merge multi-product" begin
            g1 = Graph([])
            g2 = Graph([], factor=2)
            g3 = Graph([], factor=3)
            h1 = Graph([g1, g2, g1, g1, g3, g2]; subgraph_factors=[3, 2, 5, 1, 1, 3], operator=Graphs.Prod())
            h1_mp = merge_multi_product(h1)
            h1_s1 = Graph([g1], operator=Graphs.Power(3))
            h1_s2 = Graph([g2], operator=Graphs.Power(2))
            h1_r = Graph([h1_s1, h1_s2, g3], subgraph_factors=[15, 6, 1], operator=Graphs.Prod())
            @test isequiv(h1_r, h1_mp, :id)
            merge_multi_product!(h1)
            @test isequiv(h1, h1_mp, :id)
        end
        @testset "Flatten chains" begin
            l0 = Graph([])
            l1 = Graph([l0]; subgraph_factors=[2])
            g1 = Graph([l1]; subgraph_factors=[-1], operator=O())
            g1c = deepcopy(g1)
            g2 = 2 * g1
            g3 = Graph([g2,]; subgraph_factors=[3,], operator=Graphs.Prod())
            g4 = Graph([g3,]; subgraph_factors=[5,], operator=Graphs.Prod())
            r1 = Graph([g4,]; subgraph_factors=[7,], operator=Graphs.Prod())
            r2 = Graph([g4,]; subgraph_factors=[-1,], operator=Graphs.Prod())
            r3 = Graph([g3, g4,]; subgraph_factors=[2, 7], operator=O())
            rvec = deepcopy([r1, r2, r3])
            Graphs.flatten_chains!(r1)
            @test isequiv(g1, g1c, :id)
            @test isequiv(r1, 210g1, :id)
            @test isequiv(g2, 2g1, :id)
            @test isequiv(g3, 6g1, :id)
            @test isequiv(g4, 30g1, :id)
            Graphs.flatten_chains!(r2)
            @test isequiv(r2, -30g1, :id)
            Graphs.flatten_chains!(r3)
            @test isequiv(r3, Graph([g1, g1,]; subgraph_factors=[12, 210], operator=O()), :id)
            @test r1 == Graphs.flatten_chains(rvec[1])
            @test r2 == Graphs.flatten_chains(rvec[2])
            @test r3 == Graphs.flatten_chains(rvec[3])
        end
        @testset "Remove zero-valued subgraphs" begin
            # leaves
            l1 = Graph([]; factor=1)
            l2 = Graph([]; factor=2)
            l3 = Graph([]; factor=3)
            l4 = Graph([]; factor=4)
            l5 = Graph([]; factor=5)
            l6 = Graph([]; factor=6)
            l7 = Graph([]; factor=7)
            l8 = Graph([]; factor=8)
            l2_test = Graph([]; factor=2)
            Graphs.remove_zero_valued_subgraphs(l2)
            @test isequiv(l2, l2_test, :id)
            # subgraphs
            sg1 = l1
            sg2 = Graph([l2, l3]; subgraph_factors=[1.0, 0.0], operator=Graphs.Sum())
            sg2_test = Graph([l2]; subgraph_factors=[1.0], operator=Graphs.Sum())
            sg3 = Graph([l4]; subgraph_factors=[0], operator=Graphs.Power(2))
            sg3_test = Graph([l4]; subgraph_factors=[0], operator=Graphs.Power(2))
            sg4 = Graph([l5, l6, l7]; subgraph_factors=[0, 0, 0], operator=Graphs.Sum())
            sg5 = l8
            sg6 = Graph([l2, l3]; subgraph_factors=[1.0, 0.0], operator=Graphs.Prod())
            sg6c = deepcopy(sg6)
            sg6c_test = Graph([l3]; subgraph_factors=[0.0], operator=Graphs.Prod()) 
            Graphs.remove_zero_valued_subgraphs!(sg2)
            Graphs.remove_zero_valued_subgraphs!(sg3)
            @test isequiv(sg2, sg2_test, :id)
            @test isequiv(sg3, sg3_test, :id)
            @test isequiv(sg6, sg6c, :id)
            # graphs
            g = Graph([sg1, sg2, sg3, sg4, sg5]; subgraph_factors=[1, 1, 1, 1, 0], operator=Graphs.Sum())
            g_test = Graph([sg1, sg2]; subgraph_factors=[1, 1], operator=Graphs.Sum())
            g1 = Graph([sg1, sg2, sg3, sg4, sg5, sg6]; subgraph_factors=[1, 1, 1, 1, 0, 2], operator=Graphs.Sum())
            g1_test = Graph([sg1, sg2]; subgraph_factors=[1, 1], operator=Graphs.Sum())
            g2 = Graph([sg1, sg2, sg3, sg4, sg5, sg6]; subgraph_factors=[1, 1, 1, 1, 0, 2], operator=O1())
            g2_test = Graph([sg1, sg2, sg3, sg4, sg5, sg6]; subgraph_factors=[1, 1, 1, 1, 0, 2], operator=O1())
            gp = Graph([sg3, sg4, sg5]; subgraph_factors=[1, 1, 0], operator=Graphs.Sum())
            gp_test = Graph([sg3]; subgraph_factors=[0], operator=Graphs.Sum())
            Graphs.remove_zero_valued_subgraphs!(g)
            Graphs.remove_zero_valued_subgraphs!(g1)
            Graphs.remove_zero_valued_subgraphs!(gp)
            @test isequiv(g, g_test, :id)
            @test isequiv(g1, g1_test, :id)
            @test isequiv(g2, g2_test, :id)
            @test isequiv(gp, gp_test, :id)
        end
    end
    @testset verbose = true "Optimizations" begin
        @testset "Flatten all chains" begin
            l0 = Graph([])
            l1 = Graph([l0]; subgraph_factors=[2])
            l2 = Graph([]; factor=3)
            g1 = Graph([l1, l2]; subgraph_factors=[-1, 1])
            g2 = 2 * g1
            g3 = Graph([g2,]; subgraph_factors=[3,], operator=Graphs.Prod())
            g4 = Graph([g3,]; subgraph_factors=[5,], operator=Graphs.Prod())
            r1 = Graph([g4,]; subgraph_factors=[7,], operator=Graphs.Prod())
            r2 = Graph([g4,]; subgraph_factors=[-1,], operator=Graphs.Prod())
            r3 = Graph([g3, g4,]; subgraph_factors=[2, 7], operator=O())
            rvec = deepcopy([r1, r2, r3])
            rvec1 = deepcopy([r1, r2, r3])
            Graphs.flatten_all_chains!(r1)
            @test isequiv(g1, Graph([l0, l0]; subgraph_factors=[-2, 3]), :id)
            @test isequiv(r1, 210g1, :id)
            @test isequiv(g2, 2g1, :id)
            @test isequiv(g3, 6g1, :id)
            @test isequiv(g4, 30g1, :id)
            Graphs.flatten_all_chains!(r2)
            @test isequiv(r2, -30g1, :id)
            Graphs.flatten_all_chains!(r3)
            @test isequiv(r3, Graph([g1, g1,]; subgraph_factors=[12, 210], operator=O()), :id)
            Graphs.flatten_all_chains!(rvec)
            @test rvec == [r1, r2, r3]
        end
        @testset "Remove all zero-valued subgraphs" begin
            # leaves
            l1 = Graph([]; factor=1)
            l2 = Graph([]; factor=2)
            l3 = Graph([]; factor=3)
            l4 = Graph([]; factor=4)
            l5 = Graph([]; factor=5)
            l6 = Graph([]; factor=6)
            l7 = Graph([]; factor=7)
            l8 = Graph([]; factor=8)
            # sub-subgraph
            ssg1 = Graph([l7]; subgraph_factors=[0], operator=O())
            # subgraphs
            sg1 = l1
            sg2 = Graph([l2, l3]; subgraph_factors=[1.0, 0.0], operator=Graphs.Sum())
            sg2c = deepcopy(sg2)
            sg2_test = Graph([l2]; subgraph_factors=[1.0], operator=Graphs.Sum())
            sg3 = Graph([l4]; subgraph_factors=[0], operator=Graphs.Sum())
            sg4 = Graph([l5, l6, ssg1]; subgraph_factors=[0, 0, 3], operator=Graphs.Sum())
            sg4c = deepcopy(sg4)
            sg4_test = Graph([ssg1], subgraph_factors=[3], operator=Graphs.Sum())
            sg5 = l8
            sg6 = Graph([l2, sg3]; subgraph_factors=[1.0, 2.0], operator=Graphs.Prod())
            # graphs
            g = Graph([sg1, sg2, sg3, sg4, sg5]; subgraph_factors=[1, 1, 1, 1, 0], operator=Graphs.Sum())
            g_test = Graph([sg1, sg2_test, sg4_test]; subgraph_factors=[1, 1, 1], operator=Graphs.Sum())
            g1 = Graph([sg1, sg2, sg3, sg4, sg5, sg6]; subgraph_factors=[1, 1, 1, 1, 0, -1], operator=Graphs.Sum())
            g1_test = Graph([sg1, sg2_test, sg4_test]; subgraph_factors=[1, 1, 1], operator=Graphs.Sum())
            
            g2 = Graph([sg1, sg2c, sg3, sg4c, sg5, sg6]; subgraph_factors=[1, 0, 1, 1, 0, -1], operator=O1())
            g2_test = Graph([sg1, sg2_test, sg3, sg4_test, sg5, sg6]; subgraph_factors=[1, 0, 0, 1, 0, 0], operator=O1())
            gp = Graph([sg3, sg4, sg5]; subgraph_factors=[1, 0, 0], operator=Graphs.Sum())
            gp_test = Graph([sg3]; subgraph_factors=[0], operator=Graphs.Sum())
            Graphs.remove_all_zero_valued_subgraphs!(g)
            Graphs.remove_all_zero_valued_subgraphs!(g1)
            Graphs.remove_all_zero_valued_subgraphs!(g2)
            Graphs.remove_all_zero_valued_subgraphs!(gp)
            @test isequiv(g, g_test, :id)
            @test isequiv(g1, g1_test, :id)
            @test isequiv(g2, g2_test, :id)
            @test isequiv(gp, gp_test, :id)
        end
        @testset "Merge all linear combinations" begin
            g1 = Graph([])
            g2 = 2 * g1
            g3 = Graph([], factor=3.0)
            h = Graph([g1, g1, g3], subgraph_factors=[-1, 3, 1])
            h0 = Graph([deepcopy(h), g2])
            _h = Graph([g1, g3], subgraph_factors=[2, 1])
            hvec = repeat([deepcopy(h)], 3)
            # Test on a single graph
            Graphs.merge_all_linear_combinations!(h)
            @test isequiv(h, _h, :id)
            # Test on a vector of graphs
            Graphs.merge_all_linear_combinations!(hvec)
            @test all(isequiv(h, _h, :id) for h in hvec)

            Graphs.merge_all_linear_combinations!(h0)
            @test isequiv(h0.subgraphs[1], _h, :id)
        end
        @testset "Merge all multi-products" begin
            g1 = Graph([])
            g2 = Graph([], factor=2)
            g3 = Graph([], factor=3)
            h = Graph([g1, g2, g1, g1, g3, g2]; subgraph_factors=[3, 2, 5, 1, 1, 3], operator=Graphs.Prod())
            hvec = repeat([deepcopy(h)], 3)
            h0 = Graph([deepcopy(h), g2])
            h_s1 = Graph([g1], operator=Graphs.Power(3))
            h_s2 = Graph([g2], operator=Graphs.Power(2))
            _h = Graph([h_s1, h_s2, g3], subgraph_factors=[15, 6, 1], operator=Graphs.Prod())
            # Test on a single graph
            Graphs.merge_all_multi_products!(h)
            @test isequiv(h, _h, :id)
            # Test on a vector of graphs
            Graphs.merge_all_multi_products!(hvec)
            @test all(isequiv(h, _h, :id) for h in hvec)

            Graphs.merge_all_multi_products!(h0)
            @test isequiv(h0.subgraphs[1], _h, :id)
        end
        @testset "optimize" begin
            g1 = Graph([])
            g2 = 2 * g1
            g3 = Graph([g2,]; subgraph_factors=[3,], operator=Graphs.Prod())
            g4 = Graph([g3,]; subgraph_factors=[5,], operator=Graphs.Prod())
            g5 = Graph([], factor=3.0, operator=O())
            h0 = Graph([g1, g4, g5], subgraph_factors=[2, -1, 1])
            h1 = Graph([h0], operator=Graphs.Prod(), subgraph_factors=[2])
            h = Graph([h1, g5])

            g1p = Graph([], operator=O())
            _h = Graph([Graph([g1, g1p], subgraph_factors=[-28, 3]), g1p], subgraph_factors=[2, 3])

            hvec_op = Graphs.optimize(repeat([deepcopy(h)], 3))
            @test all(isequiv(h, _h, :id) for h in hvec_op)
            @test Graphs.eval!(hvec_op[1], randseed=1) ≈ Graphs.eval!(_h, randseed=1)

            Graphs.optimize!([h])
            @test isequiv(h, _h, :id, :weight)
            @test Graphs.eval!(h, randseed=2) ≈ Graphs.eval!(_h, randseed=2)
        end
    end
    @testset "String representations" begin
        Graphs.uidreset()
        g1 = Graph([])
        g2 = 2 * g1
        g3 = Graph([g1,], subgraph_factors=[3], operator=Graphs.Sum(), name="g3")
        g4 = Graph([g1,], operator=Graphs.Power(2), name="g4")
        @test string(g1) == repr(g1) == "1: 0.0"
        @test repr(g2) == "2: Ⓧ (1)=0.0"
        @test repr(g3) == "3: g3=⨁(1)=0.0"
        @test repr(g4) == "4: g4=^2(1)=0.0"
        @test string(g2) == "2: Prod(1)=0.0"
        @test string(g3) == "3: g3=Sum(1)=0.0"
        @test string(g4) == "4: g4=Power{2}(1)=0.0"
    end
end

@testset verbose = true "FeynmanGraph" begin
    @testset verbose = true "Operations" begin
        V = [interaction(𝑓⁺(1)𝑓⁻(2)𝑓⁺(3)𝑓⁻(4)), interaction(𝑓⁺(5)𝑓⁺(6)𝑓⁻(7)𝑓⁻(8)),
            external_vertex(𝑓⁺(9)), external_vertex(𝑓⁺(10))]
        g1 = FeynmanGraph(V; topology=[[2, 6], [3, 7], [4, 9], [8, 10]],
            external_indices=[1, 5, 9, 10], external_legs=[false, false, true, true])
        g2 = g1 * 2
        g2p = FeynmanGraph(V; topology=[[2, 6], [3, 7], [4, 9], [8, 10]],
            external_indices=[1, 5, 9, 10], external_legs=[false, false, true, true], factor=2)
        @testset "Properties" begin
            @test diagram_type(g1) == Graphs.GenericDiag
            @test orders(g1) == zeros(Int, 16)
            @test vertices(g1) == OperatorProduct[𝑓⁺(1)𝑓⁻(2)𝑓⁺(3)𝑓⁻(4), 𝑓⁺(5)𝑓⁺(6)𝑓⁻(7)𝑓⁻(8), 𝑓⁺(9), 𝑓⁺(10)]
            @test topology(g1) == [[2, 6], [3, 7], [4, 9], [8, 10]]
            @test external_indices(g1) == [1, 5, 9, 10]
            @test external_operators(g1) == 𝑓⁺(1)𝑓⁺(5)𝑓⁺(9)𝑓⁺(10)
            @test external_legs(g1) == [false, false, true, true]
            properties = FeynmanProperties(
                diagram_type(g1),
                vertices(g1),
                topology(g1),
                external_indices(g1),
                external_legs(g1),
            )
            properties_no_topology = FeynmanProperties(
                diagram_type(g1),
                vertices(g1),
                [],
                external_indices(g1),
                external_legs(g1),
            )
            @test properties == g1.properties
            @test properties != properties_no_topology
            @test properties_no_topology == drop_topology(g1.properties)
        end
        @testset "Equivalence" begin
            g1_new_instance = FeynmanGraph(V; topology=[[2, 6], [3, 7], [4, 9], [8, 10]],
                external_indices=[1, 5, 9, 10], external_legs=[false, false, true, true])
            g1_from_properties = FeynmanGraph(V, g1.properties)
            # Test equivalence modulo fields id/factor
            @test isequiv(g1, g1_new_instance) == false
            @test isequiv(g1, g1_from_properties) == false
            @test isequiv(g1, g2p, :id) == false
            @test isequiv(g1, g1_new_instance, :id)
            @test isequiv(g1, g1_from_properties, :id)
            @test isequiv(g1, eldest(g2p), :id)
            # Test inequivalence when subgraph lengths are different
            t = g1 + g1
            @test isequiv(t, g1, :id) == false
        end
        @testset "Scalar multiplication" begin
            @test vertices(g2) == vertices(g1)
            println(external_operators(g2))
            println(external_operators(g1))
            @test external_operators(g2) == external_operators(g1)
            @test g2.subgraph_factors == [2]
            @test g2.operator == Graphs.Prod
            g2 = 2g1
            @test vertices(g2) == vertices(g1)
            @test external_operators(g2) == external_operators(g1)
            @test g2.subgraph_factors == [2]
            @test g2.operator == Graphs.Prod
        end
        @testset "Addition" begin
            g3 = g1 + g2
            @test vertices(g3) == vertices(g1)
            @test external_operators(g3) == external_operators(g1)
            @test g3.subgraphs == [g1]
            @test g3.subgraph_factors == [3]
            @test g3.operator == Graphs.Sum
        end
        @testset "Subtraction" begin
            g4 = g1 - g2
            @test vertices(g4) == vertices(g1)
            @test external_operators(g4) == external_operators(g1)
            @test g4.subgraphs == [g1,]
            @test g4.subgraph_factors == [-1,]
            @test g4.operator == Graphs.Sum
        end
        @testset "Linear combinations" begin
            # Binary form
            # NOTE: since g2 = 2 * g1, 5g2 ↦ 10g1 in final expressions
            g5 = 3g1 + 5g2
            g5lc = linear_combination(g1, g2, 3, 5)
            @test g5lc.subgraphs == [g1,]
            @test g5lc.subgraph_factors == [13,]
            @test isequiv(g5, g5lc, :id)
            # Vector form
            g6lc = linear_combination([g1, g2, g5, g2, g1], [3, 5, 7, 9, 11])
            @test g6lc.subgraphs == [g1,]
            @test g6lc.subgraph_factors == [133]
            # Test one-level merging of multiplicative chains
            g7lc = g1 + 2 * (3 * g1 + 5 * g2p)
            g7lc_expect = g1 + 2 * linear_combination([g1, g2p], [3, 5])
            @test isequiv(g7lc, g7lc_expect, :id)
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

    @testset verbose = true "Transformations" begin
        @testset "Relabel" begin
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
        @testset "Standardize labels" begin
            V = [𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6), 𝑓⁺(7)𝑓⁻(8)𝜙(9), 𝑓⁺(10)]
            g1 = feynman_diagram([interaction.(V[1:3]); external_vertex(V[end])], [[1, 5], [3, 9], [4, 8], [2, 10]])

            map = Dict([i => (11 - i) for i in 1:5])
            g2 = relabel(g1, map)

            g3 = standardize_labels(g2)
            uniqlabels = Graphs.collect_labels(g3)
            @test uniqlabels == [1, 2, 3, 4, 5]
        end
        @testset "Replace subgraph" begin
            V2 = [external_vertex(𝜙(1)), interaction(𝜙(2)𝜙(3)), external_vertex(𝜙(4))]
            g1 = feynman_diagram(V2, [[1, 2], [3, 4]])
            g2 = feynman_diagram(V2, [[1, 3], [2, 4]])
            g3 = feynman_diagram(V2, [[1, 4], [2, 3]])
            gsum = g2 + g3
            groot = g1 + gsum
            replace_subgraph!(groot, g2, g3)
            @test isequiv(gsum.subgraphs[1], gsum.subgraphs[2])
            gnew = replace_subgraph(groot, g2, g3)
            @test isequiv(gnew, g1 + FeynmanGraph([g3, g3], drop_topology(g3.properties)), :id)
        end
        @testset "Prune trivial unary operations" begin
            g1 = propagator(𝑓⁺(1)𝑓⁻(2))
            # +g1
            g2 = FeynmanGraph([g1,], drop_topology(g1.properties); operator=Graphs.Sum())
            # +(+g1)
            g3 = FeynmanGraph([g2,], drop_topology(g2.properties); operator=Graphs.Sum())
            # +2(+g1)
            g3p = FeynmanGraph([g2,], drop_topology(g2.properties); subgraph_factors=[2,], operator=Graphs.Sum())
            # +(+(+g1))
            g4 = FeynmanGraph([g3,], drop_topology(g3.properties); operator=Graphs.Sum())
            # +(+2(+g1))
            g4p = FeynmanGraph([g3p,], drop_topology(g3p.properties); operator=Graphs.Sum())
            @test Graphs.unary_istrivial(Graphs.Prod)
            @test Graphs.unary_istrivial(Graphs.Sum)
            g5 = FeynmanGraph([g1,], drop_topology(g1.properties); operator=O())
            @test Graphs.unary_istrivial(O) == false
        end
    end

    @testset verbose = true "Optimizations" begin
        @testset "optimize" begin
            g1 = propagator(𝑓⁻(1)𝑓⁺(2))
            g2 = 2 * g1
            g3 = FeynmanGraph([g2,], g2.properties; subgraph_factors=[3,], operator=Graphs.Prod())
            g4 = FeynmanGraph([g3,], g3.properties; subgraph_factors=[5,], operator=Graphs.Prod())
            g5 = propagator(𝑓⁻(1)𝑓⁺(2), factor=3.0, operator=O())
            h0 = FeynmanGraph([g1, g4, g5], subgraph_factors=[2, -1, 1])
            h1 = FeynmanGraph([h0], operator=Graphs.Prod(), subgraph_factors=[2])
            h = FeynmanGraph([h1, g5])
            g1p = eldest(g5)
            _h = FeynmanGraph([FeynmanGraph([g1, g1p], subgraph_factors=[-28, 3]), g1p], subgraph_factors=[2, 3])

            hvec_op = Graphs.optimize(repeat([deepcopy(h)], 3))
            @test all(isequiv(h, _h, :id) for h in hvec_op)
            @test Graphs.eval!(hvec_op[1], randseed=1) ≈ Graphs.eval!(_h, randseed=1)

            Graphs.optimize!([h])
            @test isequiv(h, _h, :id, :weight)
            @test Graphs.eval!(h, randseed=2) ≈ Graphs.eval!(_h, randseed=2)
        end
    end

    @testset "FeynmanGraphVector" begin
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

    @testset "Propagator" begin
        g1 = propagator(𝑓⁺(1)𝑓⁻(2))
        @test g1.subgraph_factors == [-1]
        @test external_indices(g1) == [2, 1]
        @test vertices(g1) == [𝑓⁺(1), 𝑓⁻(2)]
        @test external_operators(g1) == 𝑓⁻(2)𝑓⁺(1)
        @test external_labels(g1) == [2, 1]
    end

    @testset "Interaction" begin
        ops = 𝑓⁺(1)𝑓⁻(2)𝑓⁻(3)𝑓⁺(4)𝜙(5)
        g1 = interaction(ops)
        @test isempty(g1.subgraph_factors)
        @test external_indices(g1) == [1, 2, 3, 4, 5]
        @test vertices(g1) == [ops]
        @test external_operators(g1) == ops
        @test external_labels(g1) == [1, 2, 3, 4, 5]

        g2 = interaction(ops, reorder=normal_order)
        @test g2.subgraph_factors == [-1]
        @test vertices(g2) == [ops]
        @test external_operators(g2) == 𝑓⁺(1)𝑓⁺(4)𝜙(5)𝑓⁻(3)𝑓⁻(2)
        @test external_labels(g2) == [1, 4, 5, 3, 2]
    end

    @testset verbose = true "Feynman diagram" begin
        @testset "Phi4" begin
            # phi theory 
            V1 = [interaction(𝜙(1)𝜙(2)𝜙(3)𝜙(4))]
            g1 = feynman_diagram(V1, [[1, 2], [3, 4]])    #vacuum diagram
            @test vertices(g1) == [𝜙(1)𝜙(2)𝜙(3)𝜙(4)]
            @test isempty(external_operators(g1))
            @test g1.subgraph_factors == [1, 1, 1]
        end
        @testset "Complex scalar field" begin
            #complex scalar field
            V2 = [𝑏⁺(1), 𝑏⁺(2)𝑏⁺(3)𝑏⁻(4)𝑏⁻(5), 𝑏⁺(6)𝑏⁺(7)𝑏⁻(8)𝑏⁻(9), 𝑏⁻(10)]
            g2V = [external_vertex(V2[1]), interaction(V2[2]), interaction(V2[3]), external_vertex(V2[4])]
            g2 = feynman_diagram(g2V, [[1, 5], [2, 8], [3, 9], [4, 6], [7, 10]])    # Green2
            @test vertices(g2) == V2
            @test external_operators(g2) == 𝑏⁺(1)𝑏⁻(10)
            @test g2.subgraph_factors == ones(Int, 9)
        end
        @testset "Yukawa interaction" begin
            # Yukawa 
            V3 = [𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6)]
            g3 = feynman_diagram(interaction.(V3), [[1, 5], [2, 4], [3, 6]])  #vacuum diagram
            @test vertices(g3) == V3
            @test isempty(external_operators(g3))
            @test g3.subgraph_factors == ones(Int, 5)
            @test g3.subgraphs[3].subgraph_factors == [-1]
            @test vertices(g3.subgraphs[3]) == [𝑓⁺(1), 𝑓⁻(5)]
            @test external_operators(g3.subgraphs[3]) == 𝑓⁻(5)𝑓⁺(1)

            V4 = [𝑓⁺(1)𝑓⁻(2), 𝑓⁺(3)𝑓⁻(4)𝜙(5), 𝑓⁺(6)𝑓⁻(7)𝜙(8), 𝑓⁺(9)𝑓⁻(10)]
            g4 = feynman_diagram([external_vertex(V4[1]), interaction.(V4[2:3])..., external_vertex(V4[4])],
                [[1, 4], [2, 6], [3, 10], [5, 8], [7, 9]]) # polarization diagram
            @test g4.subgraph_factors == [-1]
            @test eldest(g4).subgraph_factors == ones(Int, 9)
            @test vertices(g4) == V4
            @test external_operators(g4) == 𝑓⁺(1)𝑓⁻(2)𝑓⁺(9)𝑓⁻(10)

            V5 = [𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6), 𝑓⁺(7)𝑓⁻(8)𝜙(9)]
            g5 = feynman_diagram(interaction.(V5), [[1, 5], [3, 9], [4, 8]])  # vertex function
            @test g5.subgraph_factors == [-1]
            @test eldest(g5).subgraph_factors == ones(Int, 6)
            @test vertices(g5) == V5
            @test external_operators(g5) == 𝑓⁻(2)𝜙(6)𝑓⁺(7)
            g5p = feynman_diagram(interaction.(V5), [[1, 5], [3, 9], [4, 8]], [3, 1, 2])
            @test g5p.subgraph_factors == ones(Int, 6)
            @test external_operators(g5p) == 𝑓⁺(7)𝑓⁻(2)𝜙(6)

            V6 = [𝑓⁻(8), 𝑓⁺(1), 𝑓⁺(2)𝑓⁻(3)𝜙(4), 𝑓⁺(5)𝑓⁻(6)𝜙(7)]
            g6 = feynman_diagram([external_vertex.(V6[1:2]); interaction.(V6[3:4])], [[2, 4], [3, 7], [5, 8], [6, 1]])    # fermionic Green2
            @test g6.subgraph_factors == [-1]
            @test eldest(g6).subgraph_factors == ones(Int, 8)
            @test external_operators(g6) == 𝑓⁻(8)𝑓⁺(1)

            V7 = [𝑓⁻(7), 𝑓⁺(1)𝑓⁻(2)𝜙(3), 𝑓⁺(4)𝑓⁻(5)𝜙(6)]
            g7 = feynman_diagram([external_vertex(V7[1]), interaction.(V7[2:3])...], [[2, 6], [4, 7], [5, 1]])     # sigma*G
            @test g7.subgraph_factors == ones(Int, 6)
            @test external_operators(g7) == 𝑓⁻(7)𝑓⁻(2)

            V8 = [𝑓⁺(2), 𝑓⁻(12), 𝑓⁺(3)𝑓⁻(4)𝜙(5), 𝑓⁺(6)𝑓⁻(7)𝜙(8), 𝑓⁺(9)𝑓⁻(10)𝜙(11), 𝑓⁺(13)𝑓⁻(14)𝜙(15)]
            g8 = feynman_diagram([external_vertex.(V8[1:2]); interaction.(V8[3:end])], [[1, 4], [3, 7], [5, 14], [6, 13], [8, 11], [9, 2]])
            @test g8.subgraph_factors == [-1]
            @test eldest(g8).subgraph_factors == ones(Int, 12)
            @test vertices(g8) == V8
            @test external_operators(g8) == 𝑓⁺(2)𝑓⁻(12)𝑓⁻(10)𝑓⁺(13)

            g8p = feynman_diagram([external_vertex.(V8[1:2]); interaction.(V8[3:end])],
                [[1, 4], [3, 7], [5, 14], [6, 13], [8, 11], [9, 2]], [2, 1])
            @test g8p.subgraph_factors == ones(Int, 12)
            @test external_operators(g8p) == 𝑓⁺(2)𝑓⁻(12)𝑓⁺(13)𝑓⁻(10)
        end
        @testset "f+f+f-f- interaction" begin
            V1 = [𝑓⁺(3), 𝑓⁺(4), 𝑓⁺(5)𝑓⁺(6)𝑓⁻(7)𝑓⁻(8), 𝑓⁺(9)𝑓⁺(10)𝑓⁻(11)𝑓⁻(12)]
            g1 = feynman_diagram([external_vertex.(V1[1:2]); interaction.(V1[3:4])], [[1, 6], [2, 9], [4, 10], [5, 7]])
            g1p = feynman_diagram([external_vertex.(V1[2:-1:1]); interaction.(V1[3:4])],
                [[2, 6], [1, 9], [4, 10], [5, 7]], [2, 1])
            @test g1p.subgraph_factors ≈ g1.subgraph_factors
            @test external_operators(g1) == 𝑓⁺(3)𝑓⁺(4)𝑓⁺(5)𝑓⁺(10)
            @test vertices(g1p) == [𝑓⁺(4), 𝑓⁺(3), 𝑓⁺(5)𝑓⁺(6)𝑓⁻(7)𝑓⁻(8), 𝑓⁺(9)𝑓⁺(10)𝑓⁻(11)𝑓⁻(12)]
            @test external_operators(g1p) == 𝑓⁺(4)𝑓⁺(3)𝑓⁺(10)𝑓⁺(5)

            V2 = [𝑓⁺(2), 𝑓⁻(3), 𝑓⁺(4)𝑓⁺(5)𝑓⁻(6)𝑓⁻(7), 𝑓⁺(8)𝑓⁺(9)𝑓⁻(10)𝑓⁻(11)]
            g2 = feynman_diagram([external_vertex.(V2[1:2]); interaction.(V2[3:4])], [[1, 6], [2, 3], [4, 10], [5, 8]])
            @test g2.subgraph_factors == [-1]
            @test eldest(g2).subgraph_factors == ones(Int, 8)
            @test external_operators(g2) == 𝑓⁺(2)𝑓⁻(3)𝑓⁺(8)𝑓⁻(10)
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
            @test external_operators(g) == reduce(*, V3)
        end
    end

    @testset verbose = true "String representations" begin
        Graphs.uidreset()
        g1 = propagator(𝑓⁻(1)𝑓⁺(2))
        g1p = propagator(𝑓⁻(1)𝑓⁺(2); name="g1p")
        @test repr(g1) == "1: f⁻(1)|f⁺(2)=0.0"
        @test repr(g1p) == "2: g1p, f⁻(1)|f⁺(2)=0.0"
        @test string(g1) == "1: FermiAnnihilation(1)|FermiCreation(2)=0.0"
        @test string(g1p) == "2: g1p, FermiAnnihilation(1)|FermiCreation(2)=0.0"
    end
end

@testset verbose = true "Conversions" begin
    g = Graph([]; operator=Graphs.Sum())
    g1 = Graph([]; factor=-1.0)
    g_feyn = propagator(𝑓⁺(1)𝑓⁻(2))  # equivalent to g after conversion
    # Test constructor for FeynmanGraph from Graph and FeynmanProperties
    g_feyn_conv = FeynmanGraph(g, g_feyn.properties) * (-1)
    @test isequiv(g_feyn, g_feyn_conv, :id)
    # Test implicit and explicit FeynmanGraph -> Graph conversion
    g_conv_implicit_v1::Graph = g_feyn
    g_conv_implicit_v2::Graph{Float64,Float64} = g_feyn
    g_conv_explicit_v1 = convert(Graph, g_feyn)
    g_conv_explicit_v2 = convert(Graph{Float64,Float64}, g_feyn)
    @test isequiv(g1, g_conv_implicit_v1, :id)
    @test isequiv(g1, g_conv_implicit_v2, :id)
    @test isequiv(g1, g_conv_explicit_v1, :id)
    @test isequiv(g1, g_conv_explicit_v2, :id)
end

@testset verbose = true "Evaluation" begin
    using FeynmanDiagram.ComputationalGraphs:
        eval!
    g1 = Graph([])
    g2 = Graph([], factor=2)
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
        eval!, forwardAD, node_derivative, backAD, forwardAD_root!, build_all_leaf_derivative, build_derivative_graph, burn_from_targetleaves!
    g1 = Graph([])
    g2 = Graph([])
    g3 = Graph([], factor=2.0)
    G3 = g1
    G4 = 4 * g1 * g1
    G5 = 4 * (2 * G3 + 3 * G4)
    G6 = (2 * g1 + 3 * g2) * (4 * g1 + g3) * g1
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
        @test eval!(forwardAD(G3, g1.id)) == 1
        @test eval!(forwardAD(G4, g1.id)) == 8
        @test eval!(forwardAD(G5, g1.id)) == 104
        @test eval!(forwardAD(G6, g1.id)) == 62
        @test eval!(forwardAD(G6, g2.id)) == 18
        @test eval!(forwardAD(forwardAD(G6, g1.id), g2.id)) == 30
        @test eval!(forwardAD(G6, g3.id)) == 0
        for (i, G) in enumerate([G3, G4, G5, G6, G7])
            back_deriv = backAD(G)
            for (id_pair, value_back) in back_deriv
                value_forward = forwardAD(G, id_pair[2])
                @test eval!(value_back) == eval!(value_forward)
            end
        end
    end
    @testset "forwardAD_root!" begin
        F3 = g1 + g2
        F2 = linear_combination([g1, g3, F3], [2, 1, 3])
        F1 = Graph([g1, F2, F3], operator=Graphs.Prod(), subgraph_factors=[3.0, 1.0, 1.0])

        kg1, kg2 = (g1.id, (1,)), (g2.id, (1,))
        kg3 = (eldest(g3).id, (1,))
        kF1, kF2, kF3 = (F1.id, (1,)), (F2.id, (1,)), (F3.id, (1,))

        dual = forwardAD_root!(F1)  # auto-differentation!
        @test dual[kF3].subgraphs == [dual[kg1], dual[kg2]]
        @test dual[kF2].subgraphs == [dual[kg1], dual[kg3], dual[kF3]]

        leafmap = Dict{Int,Int}()
        leafmap[g1.id], leafmap[g2.id] = 1, 2
        leafmap[eldest(g3).id] = 3
        leafmap[dual[kg1].id] = 4
        leafmap[dual[kg2].id] = 5
        leafmap[dual[kg3].id] = 6
        leaf = [1.0, 1.0, 1.0, 1.0, 0.0, 0.0]   # d F1 / d g1
        @test eval!(dual[kF1], leafmap, leaf) == 120.0
        @test eval!(dual[kF2], leafmap, leaf) == 5.0
        @test eval!(dual[kF3], leafmap, leaf) == 1.0

        leaf = [5.0, -1.0, 2.0, 0.0, 1.0, 0.0]  # d F1 / d g2
        @test eval!(dual[kF1], leafmap, leaf) == 570.0
        @test eval!(dual[kF2], leafmap, leaf) == 3.0
        @test eval!(dual[kF3], leafmap, leaf) == 1.0

        leaf = [5.0, -1.0, 2.0, 0.0, 0.0, 1.0]  # d F1 / d eldest(g3)
        @test eval!(dual[kF1], leafmap, leaf) == 120.0
        @test eval!(dual[kF2], leafmap, leaf) == 2.0
        @test eval!(dual[kF3], leafmap, leaf) == 0.0

        F0 = F1 * F3
        kF0 = (F0.id, (1,))
        dual1 = forwardAD_root!(F0)
        leafmap[dual1[kg1].id] = 4
        leafmap[dual1[kg2].id] = 5
        leafmap[dual1[kg3].id] = 6

        leaf = [1.0, 1.0, 1.0, 1.0, 0.0, 0.0]   # d F1 / d g1
        @test eval!(dual1[kF0], leafmap, leaf) == 300.0
        leaf = [5.0, -1.0, 2.0, 0.0, 1.0, 0.0]  # d F1 / d g2
        @test eval!(dual1[kF0], leafmap, leaf) == 3840.0
        leaf = [5.0, -1.0, 2.0, 0.0, 0.0, 1.0]  # d F1 / d eldest(g3)
        @test eval!(dual1[kF0], leafmap, leaf) == 480.0
        @test isequiv(dual[kF1], dual1[kF1], :id)

        F0_r1 = F1 + F3
        kF0_r1 = (F0_r1.id, (1,))
        dual = forwardAD_root!([F0, F0_r1])
        leafmap[dual[kg1].id] = 4
        leafmap[dual[kg2].id] = 5
        leafmap[dual[kg3].id] = 6
        @test eval!(dual[kF0], leafmap, leaf) == 480.0
        @test eval!(dual[kF0_r1], leafmap, leaf) == 120.0
        @test isequiv(dual[kF0], dual1[kF0], :id)
        @test isequiv(dual[kF1], dual1[kF1], :id)
    end
    @testset "build_derivative_graph" begin
        F3 = g1 + g2
        F2 = linear_combination([g1, g3, F3], [2, 1, 3])
        F1 = Graph([g1, F2, F3], operator=Graphs.Prod(), subgraph_factors=[3.0, 1.0, 1.0])

        leafmap = Dict{Int,Int}()
        leafmap[g1.id], leafmap[g2.id] = 1, 2
        leafmap[eldest(g3).id] = 3
        orders = (3, 2, 2)
        dual = Graphs.build_derivative_graph(F1, orders)

        leafmap[dual[(g1.id, (1, 0, 0))].id], leafmap[dual[(g2.id, (0, 1, 0))].id], leafmap[dual[(eldest(g3).id, (0, 0, 1))].id] = 4, 5, 6

        burnleafs_id = Int[]
        for order in Iterators.product((0:x for x in orders)...)
            order == (0, 0, 0) && continue
            for g in [g1, g2, eldest(g3)]
                if !haskey(leafmap, dual[(g.id, order)].id)
                    leafmap[dual[(g.id, order)].id] = 7
                    push!(burnleafs_id, dual[(g.id, order)].id)
                end
            end
        end
        leaf = [5.0, -1.0, 2.0, 1.0, 1.0, 1.0, 0.0]
        @test eval!(dual[(F1.id, (1, 0, 0))], leafmap, leaf) == 1002
        @test eval!(dual[(F1.id, (2, 0, 0))], leafmap, leaf) == 426
        @test eval!(dual[(F1.id, (3, 0, 0))], leafmap, leaf) == 90
        @test eval!(dual[(F1.id, (3, 1, 0))], leafmap, leaf) == 0

        # optimize the derivative graph
        c0_id = burn_from_targetleaves!([dual[(F1.id, (1, 0, 0))], dual[(F1.id, (2, 0, 0))], dual[(F1.id, (3, 0, 0))], dual[(F1.id, (3, 1, 0))]], burnleafs_id)
        if !isnothing(c0_id)
            leafmap[c0_id] = 7
        end
        @test eval!(dual[(F1.id, (1, 0, 0))], leafmap, leaf) == 1002
        @test eval!(dual[(F1.id, (2, 0, 0))], leafmap, leaf) == 426
        @test eval!(dual[(F1.id, (3, 0, 0))], leafmap, leaf) == 90
        @test eval!(dual[(F1.id, (3, 1, 0))], leafmap, leaf) == 0

        # Test on a vector of graphs
        F0 = F1 * F3
        F0_r1 = F1 + F3
        dual = Graphs.build_derivative_graph([F0, F0_r1], orders)

        leafmap = Dict{Int,Int}()
        leafmap[g1.id], leafmap[g2.id], leafmap[eldest(g3).id] = 1, 2, 3
        leafmap[dual[(g1.id, (1, 0, 0))].id], leafmap[dual[(g2.id, (0, 1, 0))].id], leafmap[dual[(eldest(g3).id, (0, 0, 1))].id] = 4, 5, 6
        burnleafs_id = Int[]
        for order in Iterators.product((0:x for x in orders)...)
            order == (0, 0, 0) && continue
            for g in [g1, g2, eldest(g3)]
                if !haskey(leafmap, dual[(g.id, order)].id)
                    leafmap[dual[(g.id, order)].id] = 7
                    push!(burnleafs_id, dual[(g.id, order)].id)
                end
            end
        end
        @test eval!(dual[(F0.id, (1, 0, 0))], leafmap, leaf) == 5568
        @test eval!(dual[(F0_r1.id, (1, 0, 0))], leafmap, leaf) == 1003
        @test eval!(dual[(F0.id, (2, 0, 0))], leafmap, leaf) == 3708
        @test eval!(dual[(F0_r1.id, (2, 0, 0))], leafmap, leaf) == 426
        @test eval!(dual[(F0.id, (3, 0, 0))], leafmap, leaf) == 1638
        @test eval!(dual[(F0_r1.id, (3, 0, 0))], leafmap, leaf) == 90
        @test eval!(dual[(F0.id, (3, 1, 0))], leafmap, leaf) == 234
        @test eval!(dual[(F0_r1.id, (3, 1, 0))], leafmap, leaf) == 0
        @test eval!(dual[(F0.id, (3, 2, 0))], leafmap, leaf) == eval!(dual[(F0_r1.id, (3, 2, 0))], leafmap, leaf) == 0

        c0_id = burn_from_targetleaves!([dual[(F0.id, (1, 0, 0))], dual[(F0.id, (2, 0, 0))], dual[(F0.id, (3, 0, 0))], dual[(F0.id, (3, 1, 0))], dual[(F0.id, (3, 2, 0))],
                dual[(F0_r1.id, (1, 0, 0))], dual[(F0_r1.id, (2, 0, 0))], dual[(F0_r1.id, (3, 0, 0))], dual[(F0_r1.id, (3, 1, 0))], dual[(F0_r1.id, (3, 2, 0))]], burnleafs_id)
        if !isnothing(c0_id)
            leafmap[c0_id] = 7
        end
        @test eval!(dual[(F0.id, (1, 0, 0))], leafmap, leaf) == 5568
        @test eval!(dual[(F0_r1.id, (1, 0, 0))], leafmap, leaf) == 1003
        @test eval!(dual[(F0.id, (2, 0, 0))], leafmap, leaf) == 3708
        @test eval!(dual[(F0_r1.id, (2, 0, 0))], leafmap, leaf) == 426
        @test eval!(dual[(F0.id, (3, 0, 0))], leafmap, leaf) == 1638
        @test eval!(dual[(F0_r1.id, (3, 0, 0))], leafmap, leaf) == 90
        @test eval!(dual[(F0.id, (3, 1, 0))], leafmap, leaf) == 234
        @test eval!(dual[(F0_r1.id, (3, 1, 0))], leafmap, leaf) == 0
        @test eval!(dual[(F0.id, (3, 2, 0))], leafmap, leaf) == eval!(dual[(F0_r1.id, (3, 2, 0))], leafmap, leaf) == 0
    end
end

@testset verbose = true "Tree properties" begin
    using FeynmanDiagram.ComputationalGraphs:
        haschildren, onechild, isleaf, isbranch, ischain, eldest, count_operation, has_zero_subfactors

    # Leaves: gᵢ
    g1 = Graph([])
    g2 = Graph([], factor=2)
    # Branches: Ⓧ --- gᵢ
    g3 = 1 * g1
    g4 = 1 * g2
    g5 = 2 * g1
    h1 = 0 * g1
    # Chains: Ⓧ --- Ⓧ --- gᵢ (simplified by default)
    g6 = Graph([g5,]; subgraph_factors=[1,], operator=Graphs.Prod())
    g7 = Graph([g3,]; subgraph_factors=[2,], operator=Graphs.Prod())
    # General trees
    g8 = 2 * (3 * g1 + 5 * g2)
    g9 = g1 + 2 * (3 * g1 + 5 * g2)
    g10 = g1 * g2 + g8 * g9
    h2 = Graph([g1, g2]; subgraph_factors=[0, 0], operator=Graphs.Sum())
    h3 = Graph([g1, g2]; subgraph_factors=[1, 0], operator=Graphs.Sum())
    h4 = Graph([g1]; subgraph_factors=[0], operator=Graphs.Power(2))
    h5 = Graph([g1, g2]; subgraph_factors=[0, 0], operator=O())
    glist = [g1, g2, g8, g9, g10]

    @testset "Leaves" begin
        @test haschildren(g1) == false
        @test onechild(g1) == false
        @test isleaf(g1)
        @test isbranch(g1) == false
        @test ischain(g1)
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
        @test isleaf(eldest(g3))
        @test has_zero_subfactors(h1, h1.operator)
    end
    @testset "Chains" begin
        @test haschildren(g6)
        @test onechild(g6)
        @test isleaf(g6) == false
        @test isbranch(g6) == false
        @test ischain(g6)
        @test isbranch(eldest(g6))
    end
    @testset "General" begin
        @test haschildren(g8)
        @test onechild(g8)
        @test isleaf(g8) == false
        @test isbranch(g8) == false
        @test ischain(g8) == false
        @test onechild(eldest(g8)) == false
        @test count_operation(g8) == [1, 0]
        @test count_operation(g9) == [2, 0]
        @test count_operation(g10) == [4, 2]
        @test has_zero_subfactors(h2, h2.operator)
        @test has_zero_subfactors(h3, h3.operator) == false
        @test has_zero_subfactors(h4, h4.operator)
        @test has_zero_subfactors(h5, h5.operator) == false
        function FeynmanDiagram.has_zero_subfactors(g::AbstractGraph, ::Type{O})
            return iszero(g.subgraph_factors)
        end
        @test has_zero_subfactors(h5, h5.operator)
    end
    @testset "Iteration" begin
        count_pre = sum(1 for node in PreOrderDFS(g9))
        count_post = sum(1 for node in PostOrderDFS(g9))
        @test count_pre == 5
        @test count_post == 5
    end
end


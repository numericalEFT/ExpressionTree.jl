push!(LOAD_PATH, pwd())
using Atom
using MCIntegration
using Lehmann
using FeynmanDiagram
using LinearAlgebra

const totalStep = 1e6
const β, U, μ = 3.0, 1.0, 1.0 / 3
const L = [1, 2]
const dim = length(L)
const Nτ = 8
const Vol = reduce(*, L)
println("β=$β, U=$U, μ=$μ, L=$L")

const model = Hubbard.hubbardAtom(:fermi, U, μ, β)
# println(length(model.c⁺))
# exit(0)
const c⁺ = collect(model.c⁺)
const c⁻ = collect(model.c⁻)
# println(model)
const T = MCIntegration.Tau(β, β / 2.0)
const O = MCIntegration.Discrete(1, 2)
O.data[1] = O.data[2] = 1
const para = GenericPara(diagType = Ver4Diag, innerLoopNum = 1, hasTau = true)

const h1 = BareHoppingId(para, (1, 1), (1, 1), (1, 2))
const h2 = BareHoppingId(para, (2, 2), (2, 2), (2, 1))

const diag1 = SCE.connectedGreen(para, [h1, h2], c⁺, c⁻)
const tree1 = ExprTree.build([diag1,], false)
const tree = [tree1,]

function DiagTree.eval(id::BareGreenNId, K, Tbasis, varT)
    if id.N == 2
        t1, t2 = T[id.extT[1]], T[id.extT[2]]
        o1, o2 = O[id.orbital[1]], O[id.orbital[2]]
        # println(t1, ", ", t2, " - ", id.creation)
        if id.creation[1]
            opt1 = Green.Heisenberg(c⁺[o1], model.E, t1)
        else
            opt1 = Green.Heisenberg(c⁻[o1], model.E, t1)
        end
        if id.creation[2]
            opt2 = Green.Heisenberg(c⁺[o2], model.E, t2)
        else
            opt2 = Green.Heisenberg(c⁻[o2], model.E, t2)
        end
        # println(opt1)
        # println(opt2)
        if t2 > t1
            return Green.thermalavg(opt2 * opt1, model.E, β, model.Z)
        else
            return -Green.thermalavg(opt1 * opt2, model.E, β, model.Z)
        end
    else
        error("not implemented!")
    end
end
DiagTree.eval(id::BareHoppingId, K, Tbasis, varT) = 1.0

# plot_tree(diag1)
DiagTree.evalDiagTree!(diag1, nothing, T.data, DiagTree.eval)
# plot_tree(diag1)
# exit(0)

function integrand(config)
    if config.curr == 1
        ExprTree.evalNaive!(tree[1], nothing, T.data)
        return tree[1][1] / 2.0 # additional factor from 1/n!
    else
        error("not implemented!")
    end
end

function measure(config)
    factor = 1.0 / config.reweight[config.curr]
    weight = integrand(config)
    config.observable[config.curr] += weight / abs(weight) * factor
end

function run(totalStep)
    dof = [[2, 2],]
    observable = zeros(1)

    # g = Green.GreenN(paraAtom.m, [0.0, extT[1]], [UP, UP])
    # g2 = Green.Gn(paraAtom.m, g)
    # println("test : $g2")

    config = MCIntegration.Configuration(totalStep, (T, O), dof, observable)
    avg, std = MCIntegration.sample(config, integrand, measure, print = 2, Nblock = 8)

    # avg[3] /= β * 2 * 4 * 2^2  #
    # std[3] /= β * 2 * 4 * 2^2

    if isnothing(avg) == false
        println(avg ./ β, " ± ", std ./ β)
    end
end

run(totalStep)

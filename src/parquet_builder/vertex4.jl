"""
    vertex4(para::GenericPara,
        extK = [DiagTree.getK(para.totalLoopNum, 1), DiagTree.getK(para.totalLoopNum, 2), DiagTree.getK(para.totalLoopNum, 3)],
        chan::AbstractVector = [PHr, PHEr, PPr, Alli],
        subdiagram = false;
        level = 1, name = :none, resetuid = false,
        phi_toplevel = ParquetBlocks().phi, ppi_toplevel = ParquetBlocks().ppi, Γ4_toplevel = ParquetBlocks().Γ4)

    Generate 4-vertex diagrams using Parquet Algorithm

# Arguments
- `para`            : parameters. It should provide internalLoopNum, interactionTauNum, firstTauIdx
- `extK`            : basis of external loops as a vector [left in, left out, right in, right out]. 
- `chan`            : vector of channels of the current 4-vertex. 
- `subdiagram`      : a sub-vertex or not
- `name`            : name of the vertex
- `level`           : level in the diagram tree
- `resetuid`        : restart uid count from 1
- `phi_toplevel`    : channels of left sub-vertex for the particle-hole and particle-hole-exchange of the bubble at level one.
- `ppi_toplevel`    : channels of left sub-vertex for the particle-particle bubble at level one
- `Γ4_toplevel`     : channels of right sub-vertex for all all bubbles at level one

# Output
- A DataFrame with fields :response, :type, :extT, :diagram, :hash
"""
function vertex4(para::GenericPara,
    extK=[DiagTree.getK(para.totalLoopNum, 1), DiagTree.getK(para.totalLoopNum, 2), DiagTree.getK(para.totalLoopNum, 3)],
    chan::AbstractVector=[PHr, PHEr, PPr, Alli], subdiagram=false;
    level=1, name=:none, resetuid=false,
    phi_toplevel=ParquetBlocks().phi, ppi_toplevel=ParquetBlocks().ppi, Γ4_toplevel=ParquetBlocks().Γ4,
    subchannel::Symbol=:All #:All, :W, :Lver3, :Rver3, :RPA
)

    for k in extK
        @assert length(k) >= para.totalLoopNum "expect dim of extK>=$(para.totalLoopNum), got $(length(k))"
    end
    extK = [k[1:para.totalLoopNum] for k in extK]
    legK = extK

    resetuid && uidreset()

    if (para.extra isa ParquetBlocks) == false
        para = reconstruct(para, extra=ParquetBlocks())
    end

    @assert para.extra isa ParquetBlocks
    @assert para.totalTauNum >= maxVer4TauIdx(para) "Increase totalTauNum!\n$para"
    @assert para.totalLoopNum >= maxVer4LoopIdx(para) "Increase totalLoopNum\n$para"

    phi, ppi = para.extra.phi, para.extra.ppi

    @assert (PHr in phi) == false "PHi vertex is particle-hole irreducible, so that PHr channel is not allowed in $phi"
    @assert (PPr in ppi) == false "PPi vertex is particle-particle irreducible, so that PPr channel is not allowed in $ppi"
    @assert (PHr in phi_toplevel) == false "PHi vertex is particle-hole irreducible, so that PHr channel is not allowed in $phi_toplevel"
    @assert (PPr in ppi_toplevel) == false "PPi vertex is particle-particle irreducible, so that PPr channel is not allowed in $ppi_toplevel"

    @assert length(legK[1]) == length(legK[2]) == length(legK[3]) == para.totalLoopNum

    KinL, KoutL, KinR = legK[1], legK[2], legK[3]
    KoutR = (length(legK) > 3) ? legK[4] : KinL + KinR - KoutL
    @assert KoutR ≈ KinL + KinR - KoutL
    legK = [KinL, KoutL, KinR, KoutR]


    loopNum = para.innerLoopNum
    @assert loopNum >= 0

    # diags = Diagram{para.weightType}[]

    if loopNum == 0
        if subchannel == :W || subchannel == :RPA || subchannel == :LVer3 || subchannel == :RVer3
            permutation = [Di,]
        else
            permutation = [Di, Ex]
        end
        ver4df = bareVer4(para, legK, permutation)
        # push!(ver4df, (response =))
        # append!(diags, bareVer4(para, legK, permutation))
    else # loopNum>0
        ver4df = DataFrame(response=Response[], type=AnalyticProperty[], extT=Tuple{Int,Int,Int,Int}[], diagram=Diagram{para.weightType}[])
        for c in chan
            if c == Alli
                continue
            end

            partition = orderedPartition(loopNum - 1, 4, 0)

            for p in partition

                if c == PHr || c == PHEr || c == PPr
                    bubble!(ver4df, para, legK, c, p, level, name, phi_toplevel, ppi_toplevel, Γ4_toplevel, 1.0, subchannel)
                    if (NoBubble in para.filter) && (loopNum == 1) && (c == PHr || c == PHEr)
                        #add bubble counter-diagram to remove the bubble
                        bubble!(ver4df, para, legK, c, p, level, Symbol("$(name)_counter"), phi_toplevel, ppi_toplevel, Γ4_toplevel, -1.0, :RPA)
                    end
                    # println(bub)
                end
            end
        end
        # # TODO: add envolpe diagrams
    end
    diags = ver4df.diagram
    @assert all(x -> x.id isa Ver4Id, diags) "not all id are Ver4Id! $diags"
    @assert all(x -> x.id.extK ≈ legK, diags) "not all extK are the same! $diags"

    # @assert isempty(diags) == false "got empty ver4! $chan with\n $para\n"
    if isempty(ver4df) == false
        ver4df = mergeby(ver4df, [:response, :type, :extT], name=name,
            getid=g -> Ver4Id(para, g[1, :response], g[1, :type], k=legK, t=g[1, :extT]) #generate id from the dataframe
        )
    end
    @assert all(x -> x[1] == para.firstTauIdx, ver4df.extT) "not all extT[1] are the same! $ver4df"
    # println(typeof(groups))
    return ver4df
end

function bubble!(ver4df::DataFrame, para::GenericPara, legK, chan::TwoBodyChannel, partition::Vector{Int}, level::Int, name::Symbol,
    phi_toplevel, ppi_toplevel, Γ4_toplevel, extrafactor=1.0, subchannel=:All)

    # diag = Diagram{para.weightType}[]

    TauNum = para.interactionTauNum # maximum tau number for each bare interaction
    oL, oG0, oR, oGx = partition[1], partition[2], partition[3], partition[4]
    if isValidG(para.filter, oG0) == false || isValidG(para.filter, oGx) == false
        # return diag
        return
    end

    #the first loop idx is the inner loop of the bubble!
    LoopIdx = para.firstLoopIdx
    idx, maxLoop = findFirstLoopIdx(partition, LoopIdx + 1)
    LfirstLoopIdx, G0firstLoopIdx, RfirstLoopIdx, GxfirstLoopIdx = idx
    @assert maxLoop == maxVer4LoopIdx(para)

    diagType = [Ver4Diag, GreenDiag, Ver4Diag, GreenDiag]
    idx, maxTau = findFirstTauIdx(partition, diagType, para.firstTauIdx, TauNum)
    LfirstTauIdx, G0firstTauIdx, RfirstTauIdx, GxfirstTauIdx = idx
    @assert maxTau == maxVer4TauIdx(para) "Partition $partition with tauNum configuration $idx. maxTau = $maxTau, yet $(maxTauIdx(para)) is expected!"

    lPara = reconstruct(para, diagType=Ver4Diag, innerLoopNum=oL, firstLoopIdx=LfirstLoopIdx, firstTauIdx=LfirstTauIdx)
    rPara = reconstruct(para, diagType=Ver4Diag, innerLoopNum=oR, firstLoopIdx=RfirstLoopIdx, firstTauIdx=RfirstTauIdx)
    gxPara = reconstruct(para, diagType=GreenDiag, innerLoopNum=oGx, firstLoopIdx=GxfirstLoopIdx, firstTauIdx=GxfirstTauIdx)
    g0Para = reconstruct(para, diagType=GreenDiag, innerLoopNum=oG0, firstLoopIdx=G0firstLoopIdx, firstTauIdx=G0firstTauIdx)

    phi, ppi, Γ4 = para.extra.phi, para.extra.ppi, para.extra.Γ4
    if chan == PHr || chan == PHEr
        Γi = (level == 1) ? phi_toplevel : phi
        Γf = (level == 1) ? Γ4_toplevel : Γ4
    elseif chan == PPr
        Γi = (level == 1) ? ppi_toplevel : ppi
        Γf = (level == 1) ? Γ4_toplevel : Γ4
    else
        error("chan $chan isn't implemented!")
    end

    LLegK, K, RLegK, Kx = legBasis(chan, legK, LoopIdx)
    # println(K, ", ", Kx)

    ls, rs = subChannel(subchannel)

    Lver = vertex4(lPara, LLegK, Γi, true; level=level + 1, name=:Γi, subchannel=ls)
    # isempty(Lver) && return diag
    isempty(Lver) && return
    # println("Γf: ", Γf)
    Rver = vertex4(rPara, RLegK, Γf, true; level=level + 1, name=:Γf, subchannel=rs)
    # isempty(Rver) && return diag
    isempty(Rver) && return

    for ldiag in Lver.diagram
        for rdiag in Rver.diagram
            extT, G0T, GxT = tauBasis(chan, ldiag.id.extT, rdiag.id.extT)
            g0 = green(g0Para, K, G0T, true, name=:G0)
            gx = green(gxPara, Kx, GxT, true, name=:Gx)
            @assert g0 isa Diagram && gx isa Diagram
            # append!(diag, bubble2diag(para, chan, ldiag, rdiag, legK, g0, gx, extrafactor))
            bubble2diag!(ver4df, para, chan, ldiag, rdiag, legK, g0, gx, extrafactor)
        end
    end
    # return diag
    return
end

function bubble2diag!(ver4df, para, chan, ldiag, rdiag, extK, g0, gx, extrafactor)
    lid, rid = ldiag.id, rdiag.id
    ln, rn = lid.response, rid.response
    lo, ro = lid.para.innerLoopNum, rid.para.innerLoopNum
    vtype = typeMap(lid.type, rid.type)

    extT, G0T, GxT = tauBasis(chan, lid.extT, rid.extT)
    Factor = factor(para, chan) * extrafactor
    spin(response) = (response == UpUp ? "↑↑" : "↑↓")

    # diag = Diagram{para.weightType}[]

    function add(Lresponse::Response, Rresponse::Response, Vresponse::Response, factor=1.0)
        if ln == Lresponse && rn == Rresponse
            nodeName = Symbol("$(spin(Lresponse))x$(spin(Rresponse)) → $chan,")
            id = Ver4Id(para, Vresponse, vtype, k=extK, t=extT, chan=chan)
            diag = Diagram(id, Prod(), [g0, gx, ldiag, rdiag], factor=factor * Factor, name=nodeName)
            push!(ver4df, (response=Vresponse, type=vtype, extT=extT, diagram=diag))
            # push!(diag, Diagram(id, Prod(), [g0, gx, ldiag, rdiag], factor=factor * Factor, name=nodeName))
        end
    end

    if chan == PHr
        add(UpUp, UpUp, UpUp, 1.0)
        add(UpDown, UpDown, UpUp, 1.0)
        add(UpUp, UpDown, UpDown, 1.0)
        add(UpDown, UpUp, UpDown, 1.0)
    elseif chan == PHEr
        add(UpUp, UpUp, UpUp, 1.0)
        add(UpUp, UpUp, UpDown, 1.0)
        add(UpDown, UpDown, UpUp, 1.0)
        add(UpDown, UpDown, UpDown, 1.0)
        #! the sign here is from the spin symmetry, not from the fermionic statistics
        add(UpUp, UpDown, UpDown, -1.0)
        #! the sign here is from the spin symmetry, not from the fermionic statistics
        add(UpDown, UpUp, UpDown, -1.0)
    elseif chan == PPr
        add(UpUp, UpUp, UpUp, 1.0)
        #! the sign here is from the spin symmetry, not from the fermionic statistics
        add(UpDown, UpDown, UpDown, -2.0)
        add(UpUp, UpDown, UpDown, 1.0)
        add(UpDown, UpUp, UpDown, 1.0)
    else
        error("chan $chan isn't implemented!")
    end

    # return diag
    return
end

function _bare(para::GenericPara, diex::Vector{Permutation}, response::Response, type::AnalyticProperty,
    _diex::Permutation, _innerT::Tuple{Int,Int}, _q, _factor=1.0)
    @assert _diex == Di || _diex == Ex

    # there is an overall sign coming from Taylor expansion of exp(-S) depsite the statistics
    if _diex == Di
        sign = -1.0
    elseif _diex == Ex
        sign = para.isFermi ? 1.0 : -1.0
    else
        error("not implemented!")
    end

    if notProper(para, _q) == false && _diex in diex
        #create new bare ver4 only if _diex is required in the diex table 
        vid = BareInteractionId(para, response, type, k=_q, t=_innerT, permu=_diex)
        return Diagram(vid, factor=sign * _factor)
    else
        return nothing
    end
end

function _pushbarever4!(para::GenericPara, nodes::DataFrame, response::Response, type::AnalyticProperty, _extT, legK,
    vd::Union{Nothing,Diagram{W}}, ve::Union{Nothing,Diagram{W}}) where {W}

    if isnothing(vd) == false
        id_di = Ver4Id(para, response, type, k=legK, t=_extT[DI])
        push!(nodes, (response=response, type=type, extT=_extT[DI], diagram=Diagram(id_di, Sum(), [vd,])))
    end

    if isnothing(ve) == false
        id_ex = Ver4Id(para, response, type, k=legK, t=_extT[EX])
        push!(nodes, (response=response, type=type, extT=_extT[EX], diagram=Diagram(id_ex, Sum(), [ve,])))
    end
end

function _pushbarever4_with_response!(para::GenericPara, nodes::DataFrame, response::Response, type::AnalyticProperty,
    legK, q, diex::Vector{Permutation}, _extT, _innerT)
    # println(_extT, " and inner: ", _innerT)
    if response == UpUp
        vd = _bare(para, diex, response, type, Di, _innerT[DI], q[DI])
        ve = _bare(para, diex, response, type, Ex, _innerT[EX], q[EX])
        _pushbarever4!(para, nodes, UpUp, type, _extT, legK, vd, ve)
    elseif response == UpDown
        vd = _bare(para, diex, UpDown, type, Di, _innerT[DI], q[DI])
        ve = nothing
        _pushbarever4!(para, nodes, UpDown, type, _extT, legK, vd, ve)
    elseif response == ChargeCharge
        # UpUp channel
        vuud = _bare(para, diex, ChargeCharge, type, Di, _innerT[DI], q[DI])
        vuue = _bare(para, diex, ChargeCharge, type, Ex, _innerT[EX], q[EX])
        _pushbarever4!(para, nodes, UpUp, type, _extT, legK, vuud, vuue)

        # UpDown channel
        vupd = _bare(para, diex, ChargeCharge, type, Di, _innerT[DI], q[DI])
        vupe = nothing
        # UpDown, exchange channel doesn't exist for the charge-charge interaction
        _pushbarever4!(para, nodes, UpDown, type, _extT, legK, vupd, vupe)
    elseif response == SpinSpin
        # see manual/interaction.md for more details

        # UpUp channel
        vuud = _bare(para, diex, SpinSpin, type, Di, _innerT[DI], q[DI])
        vuue = _bare(para, diex, SpinSpin, type, Ex, _innerT[EX], q[EX])
        _pushbarever4!(para, nodes, UpUp, type, _extT, legK, vuud, vuue)

        # UpDown channel
        vupd = _bare(para, diex, SpinSpin, type, Di, _innerT[DI], q[DI], -1.0)
        vupe = _bare(para, diex, SpinSpin, type, Ex, _innerT[EX], q[EX], 2.0)
        _pushbarever4!(para, nodes, UpDown, type, _extT, legK, vupd, vupe)
    else
        error("not implemented!")
    end
end

function bareVer4(para::GenericPara, legK, diex::Vector{Permutation}=[Di, Ex])
    # @assert para.diagType == Ver4Diag

    KinL, KoutL, KinR = legK[1], legK[2], legK[3]
    t0 = para.firstTauIdx

    nodes = DataFrame(response=Response[], type=AnalyticProperty[], extT=Tuple{Int,Int,Int,Int}[], diagram=Diagram{para.weightType}[])
    # nodes = Diagram{para.weightType}[]

    q = [KinL - KoutL, KinR - KoutL]

    """
    extT is a Tuple{Int, Int, Int, Int} of four tau indices of the external legs.
    innerT is a Tuple{Int, Int} of two tau indices of the bare interaction. 
    The innerT doesn't have to be the same of extT. Because the instant interaction is 
    independent of the tau variables, this gives a freedom how to choose the actual tau variables. 
    See Line 346 for more details.
    """
    if para.hasTau
        extT_ins = [(t0, t0, t0, t0), (t0, t0, t0, t0)]
        extT_dyn = [(t0, t0, t0 + 1, t0 + 1), (t0, t0 + 1, t0 + 1, t0)]
        innerT_ins = [(1, 1), (1, 1)]
        innerT_dyn = [(t0, t0 + 1), (t0, t0 + 1)]
    else
        extT_ins = [(t0, t0, t0, t0), (t0, t0, t0, t0)]
        extT_dyn = extT_ins
        innerT_ins = [(1, 1), (1, 1)]
        innerT_dyn = innerT_ins
    end

    for interaction in para.interaction
        response = interaction.response
        typeVec = interaction.type

        if Instant ∈ typeVec && Dynamic ∉ typeVec
            _pushbarever4_with_response!(para, nodes, response, Instant, legK, q, diex, extT_ins, innerT_ins)
        elseif Instant ∉ typeVec && Dynamic ∈ typeVec
            _pushbarever4_with_response!(para, nodes, response, Dynamic, legK, q, diex, extT_dyn, innerT_dyn)
        elseif Instant ∈ typeVec && Dynamic ∈ typeVec
            #if hasTau, instant interaction has an additional fake tau variable, making it similar to the dynamic interaction
            _pushbarever4_with_response!(para, nodes, response, Instant, legK, q, diex, extT_ins, innerT_dyn)
            _pushbarever4_with_response!(para, nodes, response, Dynamic, legK, q, diex, extT_dyn, innerT_dyn)
        end

        # if D_Instant ∈ typeVec && D_Dynamic ∉ typeVec
        #     addresponse!(response, D_Instant, extT_ins, innerT_ins)
        # elseif D_Instant ∉ typeVec && D_Dynamic ∈ typeVec
        #     addresponse!(response, D_Dynamic, extT_dyn, innerT_dyn)
        # elseif D_Instant ∈ typeVec && D_Dynamic ∈ typeVec
        #     #if hasTau, instant interaction has an additional fake tau variable, making it similar to the dynamic interaction
        #     addresponse!(response, D_Instant, extT_ins, innerT_dyn)
        #     addresponse!(response, D_Dynamic, extT_dyn, innerT_dyn)
        # end
    end

    return nodes
end

######################### utility functions ############################
maxVer4TauIdx(para) = (para.innerLoopNum + 1) * para.interactionTauNum + para.firstTauIdx - 1
maxVer4LoopIdx(para) = para.firstLoopIdx + para.innerLoopNum - 1

function legBasis(chan::TwoBodyChannel, legK, loopIdx::Int)
    KinL, KoutL, KinR, KoutR = legK[1], legK[2], legK[3], legK[4]
    K = zero(KinL)
    K[loopIdx] = 1
    if chan == PHr
        Kx = KoutL + K - KinL
        LLegK = [KinL, KoutL, Kx, K]
        RLegK = [K, Kx, KinR, KoutR]
    elseif chan == PHEr
        Kx = KoutR + K - KinL
        LLegK = [KinL, KoutR, Kx, K]
        RLegK = [K, Kx, KinR, KoutL]
    elseif chan == PPr
        Kx = KinL + KinR - K
        LLegK = [KinL, Kx, KinR, K]
        RLegK = [K, KoutL, Kx, KoutR]
    else
        error("not implemented!")
    end

    # check conservation and momentum assignment
    @assert LLegK[INL] ≈ KinL
    @assert LLegK[INL] + LLegK[INR] ≈ LLegK[OUTL] + LLegK[OUTR]
    @assert RLegK[INL] + RLegK[INR] ≈ RLegK[OUTL] + RLegK[OUTR]

    return LLegK, K, RLegK, Kx
end

function tauBasis(chan::TwoBodyChannel, LvT, RvT)
    G0T = (LvT[OUTR], RvT[INL])
    if chan == PHr
        extT = (LvT[INL], LvT[OUTL], RvT[INR], RvT[OUTR])
        GxT = (RvT[OUTL], LvT[INR])
    elseif chan == PHEr
        extT = (LvT[INL], RvT[OUTR], RvT[INR], LvT[OUTL])
        GxT = (RvT[OUTL], LvT[INR])
    elseif chan == PPr
        extT = (LvT[INL], RvT[OUTL], LvT[INR], RvT[OUTR])
        GxT = (LvT[OUTL], RvT[INR])
    else
        error("not implemented!")
    end

    # make sure all tidx are used once and only once
    t1 = sort(vcat(collect(G0T), collect(GxT), collect(extT)))
    t2 = sort(vcat(collect(LvT), collect(RvT)))
    @assert t1 == t2 "chan $(chan): G0=$G0T, Gx=$GxT, external=$extT don't match with Lver4 $LvT and Rver4 $RvT"
    @assert extT[INL] == LvT[INL]
    return extT, G0T, GxT
end


function factor(para::GenericPara, chan::TwoBodyChannel)
    # Factor = SymFactor[Int(chan)] / (2π)^para.loopDim
    Factor = SymFactor[Int(chan)]
    if para.isFermi == false
        Factor = abs(Factor)
    end
    return Factor
end

function typeMap(ltype::AnalyticProperty, rtype::AnalyticProperty)
    return Dynamic
    # if (ltype == Instant || ltype == Dynamic) && (rtype == Instant || rtype == Dynamic)
    #     return Dynamic
    # elseif (ltype == D_Instant || ltype == D_Dynamic) && (rtype == Instant || rtype == Dynamic)
    #     return D_Dynamic
    # elseif (ltype == Instant || ltype == Dynamic) && (rtype == D_Instant || rtype == D_Dynamic)
    #     return D_Dynamic
    # else
    #     return nothing
    # end
end

function subChannel(subchan)
    if subchan == :RPA
        return :RPA, :RPA
    elseif subchan == :LVer3
        return :LVer3, :All
    elseif subchan == :RVer3
        return :All, :RVer3
    elseif subchan == :W
        return :LVer3, :RVer3
    elseif subchan == :All
        return :All, :All
    else
        error("not implemented!")
    end
end
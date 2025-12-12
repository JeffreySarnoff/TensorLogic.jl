#------------------------------------------------------------------------------
# Expression -> DAG graph (for stats / DOT / JSON export)
#------------------------------------------------------------------------------
using Dictionaries

struct GraphNode
    op::Symbol
    args::Vector{Int}
    payload::Any
end

struct TLGraph
    nodes::Vector{GraphNode}
    root::Int
end

_term_label(t::TLTerm) = t isa VarT ? string((t::VarT).name) : string((t::ConstT).name)

function compile_graph(expr::TLExpr; cse::Bool=true)::TLGraph
    nodes = GraphNode[]
    memo = Dictionary{Any,Int}()

    nodekey(op,args,payload) = (op, tuple(args...), payload)

    function emit(op::Symbol, child_ids::Vector{Int}, payload=nothing)
        if cse
            k = nodekey(op, child_ids, payload)
            if _has(memo, k)
                return memo[k]
            end
            id = length(nodes) + 1
            push!(nodes, GraphNode(op, child_ids, payload))
            set!(memo, k, id)
            return id
        else
            id = length(nodes) + 1
            push!(nodes, GraphNode(op, child_ids, payload))
            return id
        end
    end

    function go(e::TLExpr)::Int
        if e isa Pred
            pe = e::Pred
            return emit(:pred, Int[], (pe.name, pe.args))
        elseif e isa AndExpr
            ee = e::AndExpr; return emit(:and, [go(ee.a), go(ee.b)])
        elseif e isa OrExpr
            ee = e::OrExpr; return emit(:or, [go(ee.a), go(ee.b)])
        elseif e isa NotExpr
            ee = e::NotExpr; return emit(:not, [go(ee.x)])
        elseif e isa ImplyExpr
            ee = e::ImplyExpr; return emit(:imply, [go(ee.a), go(ee.b)])
        elseif e isa ExistsExpr
            ee = e::ExistsExpr; return emit(:exists, [go(ee.body)], (ee.var.name, ee.domain))
        elseif e isa ForallExpr
            ee = e::ForallExpr; return emit(:forall, [go(ee.body)], (ee.var.name, ee.domain))
        else
            throw(ArgumentError("unknown TLExpr node"))
        end
    end

    root = go(expr)
    return TLGraph(nodes, root)
end

function graph_stats(g::TLGraph)
    ops = Dictionary{Symbol,Int}()
    for nd in g.nodes
        set!(ops, nd.op, _get(ops, nd.op, 0) + 1)
    end
    return (nodes=length(g.nodes), op_counts=ops)
end

function export_dot(g::TLGraph; name::AbstractString="TensorLogicExpr")
    io = IOBuffer()
    println(io, "digraph ", name, " {")
    println(io, "  rankdir=LR;")
    for (i, nd) in enumerate(g.nodes)
        label = if nd.op == :pred
            pred, args = nd.payload
            "$(pred)($(join(map(_term_label, args), ',')))"
        elseif nd.op == :exists || nd.op == :forall
            v, dom = nd.payload
            "$(nd.op) $(v):$(dom)"
        else
            string(nd.op)
        end
        println(io, "  n$i [shape=box, label=\"$(label)\"];")
        for c in nd.args
            println(io, "  n$c -> n$i;")
        end
    end
    println(io, "}")
    return String(take!(io))
end

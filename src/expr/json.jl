#------------------------------------------------------------------------------
# JSON export for expression graphs
#------------------------------------------------------------------------------
using JSON3

_term_json(t::TLTerm) =
    t isa VarT   ? (; kind="var", name=String((t::VarT).name)) :
    t isa ConstT ? (; kind="const", name=String((t::ConstT).name)) :
                   (; kind="unknown")

"""Return a JSON-serializable object for a graph."""
function export_json_obj(g::TLGraph)
    nodes = Vector{Any}(undef, length(g.nodes))
    edges = Any[]
    for (i, nd) in enumerate(g.nodes)
        payload = if nd.op == :pred
            pred, args = nd.payload
            (; pred=String(pred), args=[_term_json(a) for a in args])
        elseif nd.op == :exists || nd.op == :forall
            v, dom = nd.payload
            (; var=String(v), domain=String(dom))
        else
            nothing
        end
        nodes[i] = (; id=i, op=String(nd.op), args=nd.args, payload=payload)
        for c in nd.args
            push!(edges, (; from=c, to=i))
        end
    end
    return (; root=g.root, nodes=nodes, edges=edges)
end

"""Serialize a graph to JSON."""
export_json(g::TLGraph; indent::Int=2) = String(JSON3.write(export_json_obj(g); indent=indent))

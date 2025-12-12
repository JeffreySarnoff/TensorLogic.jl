#------------------------------------------------------------------------------
# Minimal expression parser (tutorial-style)
# Supports: pred(x,y), &, |, !, ->, exists v(:Dom)?. expr, forall ...
#------------------------------------------------------------------------------

struct _ETok
    kind::Symbol
    text::String
end

function _etokenize(src::AbstractString)
    toks = _ETok[]
    i = firstindex(src); n = lastindex(src)

    peek() = (i > n ? '\0' : src[i])
    function advance()
        c = peek()
        i <= n && (i = nextind(src, i))
        return c
    end

    while i <= n
        c = peek()
        if c in (' ', '\t', '\r', '\n')
            advance(); continue
        end
        if c == '#'
            while i <= n && peek() != '\n'
                advance()
            end
            continue
        end
        if c == '('; advance(); push!(toks,_ETok(:LP,"(")); continue; end
        if c == ')'; advance(); push!(toks,_ETok(:RP,")")); continue; end
        if c == ','; advance(); push!(toks,_ETok(:COMMA,",")); continue; end
        if c == '.'; advance(); push!(toks,_ETok(:DOT,".")); continue; end
        if c == ':'; advance(); push!(toks,_ETok(:COLON,":")); continue; end
        if c == '&'; advance(); push!(toks,_ETok(:AND,"&")); continue; end
        if c == '|'; advance(); push!(toks,_ETok(:OR,"|")); continue; end
        if c == '!'; advance(); push!(toks,_ETok(:NOT,"!")); continue; end
        if c == '-'
            advance()
            peek() == '>' || throw(ArgumentError("unexpected '-'"))
            advance()
            push!(toks,_ETok(:IMPLY,"->"))
            continue
        end

        if isletter(c) || c == '_'
            buf = IOBuffer()
            while i <= n
                d = peek()
                if isletter(d) || isdigit(d) || d == '_'
                    write(buf, advance())
                else
                    break
                end
            end
            s = String(take!(buf))
            k = s == "exists" ? :EXISTS : s == "forall" ? :FORALL : :IDENT
            push!(toks, _ETok(k, s))
            continue
        end

        throw(ArgumentError("unexpected character '$c'"))
    end
    push!(toks, _ETok(:EOF,""))
    return toks
end

mutable struct _EP
    toks::Vector{_ETok}
    i::Int
end
_epeek(p::_EP) = p.toks[p.i]
function _eeat(p::_EP, k::Symbol)
    t = _epeek(p)
    t.kind == k || throw(ArgumentError("expected $k, got $(t.kind) near '$(t.text)'"))
    p.i += 1
    return t
end
_eaccept(p::_EP, k::Symbol) = (_epeek(p).kind == k) ? (p.i += 1; true) : false

function _parse_term(p::_EP)::TLTerm
    t = _eeat(p,:IDENT)
    s = t.text
    c1 = s[1]
    return (c1 == '_' || islowercase(c1)) ? VarT(Symbol(s)) : ConstT(Symbol(s))
end

# precedence: NOT > AND > OR > IMPLY (right-assoc)
function _parse_primary(p::_EP)::TLExpr
    t = _epeek(p)
    if t.kind == :LP
        _eeat(p,:LP)
        e = _parse_imply(p)
        _eeat(p,:RP)
        return e
    elseif t.kind == :EXISTS || t.kind == :FORALL
        q = t.kind; p.i += 1
        v = Symbol(_eeat(p,:IDENT).text)
        dom = :Any
        if _eaccept(p, :COLON)
            dom = Symbol(_eeat(p,:IDENT).text)
        end
        _eeat(p, :DOT)
        body = _parse_imply(p)
        return q == :EXISTS ? exists(v, dom, body) : forall(v, dom, body)
    elseif t.kind == :NOT
        _eeat(p,:NOT)
        return not_(_parse_primary(p))
    elseif t.kind == :IDENT
        name = Symbol(_eeat(p,:IDENT).text)
        _eeat(p,:LP)
        args = TLTerm[]
        if _epeek(p).kind != :RP
            push!(args, _parse_term(p))
            while _eaccept(p,:COMMA)
                push!(args, _parse_term(p))
            end
        end
        _eeat(p,:RP)
        return pred(name, args)
    else
        throw(ArgumentError("unexpected token $(t.kind)"))
    end
end

function _parse_and(p::_EP)
    e = _parse_primary(p)
    while _eaccept(p,:AND)
        e = and_(e, _parse_primary(p))
    end
    return e
end

function _parse_or(p::_EP)
    e = _parse_and(p)
    while _eaccept(p,:OR)
        e = or_(e, _parse_and(p))
    end
    return e
end

function _parse_imply(p::_EP)
    e = _parse_or(p)
    if _eaccept(p,:IMPLY)
        rhs = _parse_imply(p)
        return imply(e, rhs)
    end
    return e
end

\"\"\"Parse tutorial-style expression language into `TLExpr`.\"\"\"
function parse_tlexpr(src::AbstractString)::TLExpr
    toks = _etokenize(src)
    p = _EP(toks, 1)
    e = _parse_imply(p)
    _epeek(p).kind == :EOF || throw(ArgumentError("unexpected trailing input"))
    return e
end

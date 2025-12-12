#------------------------------------------------------------------------------
# Surface syntax parser for rule programs:
# - Facts: Parent(Alice,Bob). or Parent[Alice,Bob].
# - Datalog rules: Head(x) :- Body(x), Other(x).
# - Bracket equation rules: Head[x] = A[x] * B[x].
#------------------------------------------------------------------------------
# Design goal: strict, small, predictable; errors are local.

struct _Tok
    kind::Symbol
    text::String
end

function _tokenize(src::AbstractString)
    toks = _Tok[]
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

        # comments (# or % to end-of-line)
        if c == '#' || c == '%'
            while i <= n && peek() != '\n'
                advance()
            end
            continue
        end

        # tokens
        if c == ':'; advance(); peek() == '-' || throw(ArgumentError("expected ':-'")); advance(); push!(toks,_Tok(:ARROW,":-")); continue; end
        if c == '+'; advance(); if peek()=='='; advance(); push!(toks,_Tok(:PLUSEQ,"+=")); else push!(toks,_Tok(:PLUS,"+")); end; continue; end
        if c == '('; advance(); push!(toks,_Tok(:LPAREN,"(")); continue; end
        if c == ')'; advance(); push!(toks,_Tok(:RPAREN,")")); continue; end
        if c == '['; advance(); push!(toks,_Tok(:LBRACK,"[")); continue; end
        if c == ']'; advance(); push!(toks,_Tok(:RBRACK,"]")); continue; end
        if c == ','; advance(); push!(toks,_Tok(:COMMA,",")); continue; end
        if c == '.'; advance(); push!(toks,_Tok(:DOT,".")); continue; end
        if c == ';'; advance(); push!(toks,_Tok(:SEMI,";")); continue; end
        if c == '*'; advance(); push!(toks,_Tok(:STAR,"*")); continue; end
        if c == '='; advance(); push!(toks,_Tok(:EQ,"=")); continue; end

        if c == '"' || c == '\''
            q = advance()
            buf = IOBuffer()
            while i <= n
                d = advance()
                d == q && break
                if d == '\\' && i <= n
                    e = advance()
                    if e == 'n'
                        write(buf, '\n')
                    elseif e == 't'
                        write(buf, '\t')
                    else
                        write(buf, e)
                    end
                else
                    write(buf, d)
                end
            end
            push!(toks, _Tok(:STRING, String(take!(buf))))
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
            # allow "AND" as comma alias (tutorial convenience)
            if uppercase(s) == "AND"
                push!(toks, _Tok(:COMMA, ","))
            else
                push!(toks, _Tok(:IDENT, s))
            end
            continue
        end

        throw(ArgumentError("unexpected character '$c'"))
    end

    push!(toks, _Tok(:EOF,""))
    return toks
end

mutable struct _P
    toks::Vector{_Tok}
    i::Int
end
_peek(p::_P) = p.toks[p.i]
function _eat(p::_P, k::Symbol)
    t = _peek(p)
    t.kind == k || throw(ArgumentError("expected $k, got $(t.kind) near '$(t.text)'"))
    p.i += 1
    return t
end
_accept(p::_P, k::Symbol) = (_peek(p).kind == k) ? (p.i += 1; true) : false

function _parse_term(p::_P)::Term
    t = _peek(p)
    if t.kind == :IDENT
        _eat(p,:IDENT)
        s = t.text
        c1 = s[1]
        return (c1 == '_' || islowercase(c1)) ? Var(Symbol(s)) : Const(Symbol(s))
    elseif t.kind == :STRING
        _eat(p,:STRING)
        return Const(Symbol(t.text))
    else
        throw(ArgumentError("expected term, got $(t.kind)"))
    end
end

function _parse_args(p::_P)
    args = Term[]
    if _accept(p,:LPAREN) || _accept(p,:LBRACK)
        closing = p.toks[p.i-1].kind == :LPAREN ? :RPAREN : :RBRACK
        if _peek(p).kind != closing
            push!(args, _parse_term(p))
            while _accept(p,:COMMA)
                push!(args, _parse_term(p))
            end
        end
        _eat(p, closing)
    end
    return args
end

_parse_atom(p::_P) = Atom(Symbol(_eat(p,:IDENT).text), _parse_args(p))

function _parse_product(p::_P)
    atoms = Atom[]
    push!(atoms, _parse_atom(p))
    while true
        if _accept(p,:STAR)
            push!(atoms, _parse_atom(p)); continue
        end
        # implicit multiplication if another atom starts
        if _peek(p).kind == :IDENT
            push!(atoms, _parse_atom(p)); continue
        end
        break
    end
    return atoms
end

_skip_delim!(p::_P) = (_accept(p,:DOT); _accept(p,:SEMI); nothing)

function _parse_stmt!(p::_P, facts::Vector{Atom}, rules::Vector{Rule})
    head = _parse_atom(p)

    if _accept(p,:ARROW)
        body = Atom[_parse_atom(p)]
        while _accept(p,:COMMA)
            push!(body, _parse_atom(p))
        end
        _skip_delim!(p)
        push!(rules, Rule(head, body))
        return
    end

    if _accept(p,:EQ) || _accept(p,:PLUSEQ)
        body = _parse_product(p)
        _skip_delim!(p)
        push!(rules, Rule(head, body))
        return
    end

    _skip_delim!(p)
    push!(facts, head)
end

"""Parse TensorLogic rule surface syntax into `IRProgram`."""
function parse_tensorlogic(src::AbstractString)::IRProgram
    toks = _tokenize(src)
    p = _P(toks, 1)
    facts = Atom[]
    rules = Rule[]
    while _peek(p).kind != :EOF
        _parse_stmt!(p, facts, rules)
    end
    return IRProgram(facts, rules)
end

parse_datalog(src::AbstractString) = parse_tensorlogic(src)
parse_equations(src::AbstractString) = parse_tensorlogic(src)

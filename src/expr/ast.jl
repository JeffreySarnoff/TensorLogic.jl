#------------------------------------------------------------------------------
# TensorLogic expression AST (tutorial-style)
#------------------------------------------------------------------------------
abstract type TLExpr end
abstract type TLTerm end

struct VarT <: TLTerm
    name::Symbol
end
struct ConstT <: TLTerm
    name::Symbol
end

struct Pred <: TLExpr
    name::Symbol
    args::Vector{TLTerm}
end
struct AndExpr <: TLExpr
    a::TLExpr
    b::TLExpr
end
struct OrExpr <: TLExpr
    a::TLExpr
    b::TLExpr
end
struct NotExpr <: TLExpr
    x::TLExpr
end
struct ImplyExpr <: TLExpr
    a::TLExpr
    b::TLExpr
end
struct ExistsExpr <: TLExpr
    var::VarT
    domain::Symbol
    body::TLExpr
end
struct ForallExpr <: TLExpr
    var::VarT
    domain::Symbol
    body::TLExpr
end

# constructors
pred(name::Symbol, args::Vector{TLTerm}) = Pred(name, args)
and_(a::TLExpr, b::TLExpr) = AndExpr(a, b)
or_(a::TLExpr, b::TLExpr)  = OrExpr(a, b)
not_(x::TLExpr)            = NotExpr(x)
imply(a::TLExpr, b::TLExpr)= ImplyExpr(a, b)
exists(var::Symbol, domain::Symbol, body::TLExpr) = ExistsExpr(VarT(var), domain, body)
forall(var::Symbol, domain::Symbol, body::TLExpr) = ForallExpr(VarT(var), domain, body)

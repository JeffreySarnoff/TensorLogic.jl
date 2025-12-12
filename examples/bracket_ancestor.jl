using TensorLogic

src = """
Parent[Alice, Bob].
Parent[Bob, Charlie].
Parent[Charlie, Dana].

Ancestor[x,y] = Parent[x,y].
Ancestor[x,z] = Ancestor[x,y] * Parent[y,z].
"""

prog = parse_tensorlogic(src)
ctx  = TLContext()
run!(ctx, prog; maxiters=50)

println("Ancestor tuples:")
for t in sort(relation_tuples(ctx, :Ancestor))
    println("  ", t)
end

using TensorLogic

# Paths but only those that end at a specific constant, using constant filtering in the body.
src = """
Edge[A,B]. Edge[B,C]. Edge[C,D]. Edge[D,E].

Path[x,y] = Edge[x,y].
Path[x,z] = Path[x,y] * Edge[y,z].

EndAtE[x] = Path[x,E].
"""

prog = parse_tensorlogic(src)
ctx = TLContext()
run!(ctx, prog; maxiters=50)

println("EndAtE tuples:")
for t in sort(relation_tuples(ctx, :EndAtE))
    println("  ", t)
end

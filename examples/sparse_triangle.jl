using TensorLogic

# Find triangles in an undirected graph using a 2-ary Edge relation.
src = """
Edge[A,B]. Edge[B,C]. Edge[C,A].
Edge[A,C]. Edge[C,D]. Edge[D,A].

Tri[x,y,z] = Edge[x,y] * Edge[y,z] * Edge[z,x].
"""

prog = parse_tensorlogic(src)
ctx = TLContext()
run!(ctx, prog; maxiters=10)

println("Triangles:")
for t in sort(relation_tuples(ctx, :Tri))
    println("  ", t)
end

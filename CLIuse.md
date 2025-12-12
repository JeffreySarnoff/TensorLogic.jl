Quick usage (from package root):

julia --project=. bin/tensorlogic -d Person:100 "tall(x)"
julia --project=. bin/tensorlogic --output-format dot "knows(x,y)" > graph.dot
julia --project=. bin/tensorlogic --output-format json "knows(x,y)" > graph.json
julia --project=. bin/tensorlogic --validate -d Person:2 "forall x:Person. knows(x,y) -> likes(x,y)"
using Documenter
using TensorLogic

DocMeta.setdocmeta!(TensorLogic, :DocTestSetup, :(using TensorLogic); recursive=true)

makedocs(
    modules=[TensorLogic],
    sitename="TensorLogic.jl",
    format=Documenter.HTML(prettyurls=false),
    pages=[
        "Home" => "index.md",
        "Rule programs (sparse)" => "rule_programs.md",
        "Expression language (dense)" => "expression_language.md",
        "CLI tool" => "cli.md",
        "Examples" => "examples.md",
        "Tri-map" => "tri_map.md",
        "Abstract model" => "abstract_model.md",
        "Design" => "design.md",
        "API" => "api.md",
    ],
)

deploydocs(repo="") # disabled by default

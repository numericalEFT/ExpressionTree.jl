using FeynmanDiagram
using Documenter

DocMeta.setdocmeta!(FeynmanDiagram, :DocTestSetup, :(using FeynmanDiagram); recursive = true)

makedocs(;
    modules = [FeynmanDiagram],
    authors = "Kun Chen, Pengcheng Hou",
    repo = "https://github.com/numericalEFT/FeynmanDiagram.jl/blob/{commit}{path}#{line}",
    sitename = "FeynmanDiagram.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://numericaleft.github.io/FeynmanDiagram.jl",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md",
        "Manual" => [
        ],
        "API reference" => Any[
            "lib/diagtree.md",
            "lib/builder.md",
            "lib/parquet.md",
        ]
    ]
)

deploydocs(;
    repo = "github.com/numericalEFT/FeynmanDiagram.jl"
)

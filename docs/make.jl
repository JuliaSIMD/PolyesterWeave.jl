using PolyesterWeave
using Documenter

DocMeta.setdocmeta!(PolyesterWeave, :DocTestSetup, :(using PolyesterWeave); recursive=true)

makedocs(;
    modules=[PolyesterWeave],
    authors="Chris Elrod <elrodc@gmail.com> and contributors",
    repo="https://github.com/chriselrod/PolyesterWeave.jl/blob/{commit}{path}#{line}",
    sitename="PolyesterWeave.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://chriselrod.github.io/PolyesterWeave.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/chriselrod/PolyesterWeave.jl",
    devbranch="main",
)

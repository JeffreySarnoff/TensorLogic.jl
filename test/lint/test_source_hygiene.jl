using Test

function _scan_sources(root::AbstractString)
    bad = String[]
    for (dirpath, _, files) in walkdir(root)
        for f in files
            endswith(f, ".jl") || continue
            path = joinpath(dirpath, f)
            lines = readlines(path)
            for (i, ln) in enumerate(lines)
                s = strip(ln)
                isempty(s) && continue
                # Disallow "markdown bullets" at column start in code.
                # This has caused reintroduced parse/precompile failures.
                if startswith(s, "- ") && !startswith(s, "#") && !startswith(s, "##")
                    push!(bad, "$(path):$(i): looks like a markdown bullet in source: $(ln)")
                end
                # Disallow escaped triple-quote sequences that indicate corruption:
                if occursin("\\\"\\\"\\\"", ln)
                    push!(bad, "$(path):$(i): escaped triple-quote sequence (\\\"\\\"\\\") detected")
                end
            end
        end
    end
    return bad
end

@testset "Source hygiene (regression guards)" begin
    bad = _scan_sources(joinpath(@__DIR__, "..", "..", "src"))
    @test isempty(bad) || begin
        @info "Source hygiene violations" bad
        false
    end
end

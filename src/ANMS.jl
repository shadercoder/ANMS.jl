module ANMS

export nelder_mead

# References:
# * Fuchang Gao and Lixing Han (2010), Springer US. "Implementing the Nelder-Mead simplex algorithm with adaptive parameters" (doi:10.1007/s10589-010-9329-3)
# * Saša Singer and John Nelder (2009), Scholarpedia, 4(7):2928. "Nelder-Mead algorithm" (doi:10.4249/scholarpedia.2928)

# Adaptive Nelder-Mead Simplex (ANMS) algorithm
function nelder_mead(f::Function, x₀::Vector{Float64}; iteration::Int=1_000_000, ftol::Float64=1.0e-8, xtol::Float64=1.0e-8)
    # diemnsion
    n = length(x₀)
    if n < 2
        error("multivariate function is needed")
    end

    # parameters of transformations
    α = 1.0
    β = 1.0 + 2 / n
    γ = 0.75 - 1 / 2n
    δ = 1.0 - 1 / n

    # initialize simplex and function values
    simplex = Vector{Float64}[x₀]
    fvalues = Float64[f(x₀)]
    u = zeros(n)
    for i in 1:n
        τ = x₀[i] == 0.0 ? 0.00025 : 0.05
        u[i] = 1.0
        x = x₀ .+ τ * u
        u[i] = 0.0
        push!(simplex, x)
        push!(fvalues, f(x))
    end
    ord = sortperm(fvalues)

    # stopping criteria
    iter = 0  # number of iterations
    domconv = false  # domain convergence
    fvalconv = false  # function-value convergence

    # centroid
    c = similar(x₀)
    # transformed points
    xr = similar(x₀)
    xe = similar(x₀)
    xc = similar(x₀)

    while !(iter >= iteration || (fvalconv && domconv))
        # DEBUG
        #@assert issorted(fvalues[ord])

        # highest, second highest, and lowest indices, respectively
        h = ord[n+1]
        s = ord[n]
        l = ord[1]

        # centroid except the highest vertex
        fill!(c, 0.0)
        @inbounds for i in 1:n+1
            if i != h
                xi = simplex[i]
                for j in 1:n
                    c[j] += xi[j]
                end
            end
        end
        for j in 1:n
            c[j] /= n
        end

        xh = simplex[h]
        fh = fvalues[h]
        # xs = simplex[s]
        fs = fvalues[s]
        xl = simplex[l]
        fl = fvalues[l]

        # reflect
        #xr = c .+ α * (c .- xh)
        @inbounds for j in 1:n
            xr[j] = c[j] + α * (c[j] - xh[j])
        end
        fr = f(xr)
        doshrink = false

        if fr < fl # <= fs
            # expand
            #xe = c .+ β * (xr .- c)
            @inbounds for j in 1:n
                xe[j] = c[j] + β * (xr[j] - c[j])
            end
            fe = f(xe)
            if fe < fr
                accept = (xe, fe)
            else
                accept = (xr, fr)
            end
        elseif fr < fs
            accept = (xr, fr)
        else # fs <= fr
            # contract
            if fr < fh
                # outside
                #xc = c .+ γ * (xr .- c)
                @inbounds for j in 1:n
                    xc[j] = c[j] + γ * (xr[j] - c[j])
                end
                fc = f(xc)
                if fc <= fr
                    accept = (xc, fc)
                else
                    doshrink = true
                end
            else
                # inside
                #xc = c .- γ * (xr .- c)
                @inbounds for j in 1:n
                    xc[j] = c[j] - γ * (xr[j] - c[j])
                end
                fc = f(xc)
                if fc < fh
                    accept = (xc, fc)
                else
                    doshrink = true
                end
            end

            if doshrink
                # shrink
                for i in 2:n+1
                    o = ord[i]
                    xi = xl .+ δ * (simplex[o] .- xl)
                    simplex[o] = xi
                    fvalues[o] = f(xi)
                end
            end
        end

        #@show doshrink
        # update simplex and function values
        if doshrink
            # TODO: use in-place sortperm (v0.4 has it!)
            ord = sortperm(fvalues)
        else
            x, fvalue = accept
            #simplex[h][:] = x[:]
            @inbounds for j in 1:n
                simplex[h][j] = x[j]
            end
            fvalues[h] = fvalue
            # insert new value into an ordered position
            @inbounds for i in n+1:-1:2
                if fvalues[ord[i-1]] > fvalues[ord[i]]
                    ord[i-1], ord[i] = ord[i], ord[i-1]
                else
                    break
                end
            end
        end

        l = ord[1]
        xl = simplex[l]
        fl = fvalues[l]

        # check convergence
        fvalconv = true
        @inbounds for i in 2:n+1
            if abs(fvalues[i] - fl) > ftol
                fvalconv = false
                break
            end
        end
        domconv = true
        @inbounds for i in 2:n+1
            # compute the infinity norm
            norm = -Inf
            for j in 1:n
                norm = max(norm, abs(simplex[i][j] - xl[j]))
            end
            if norm > xtol
                domconv = false
                break
            end
        end

        iter += 1
    end
    #@show iter domconv fvalconv
    #@show simplex fvalues

    # return the minimizing vertex and the function value
    # TODO: the value at the centroid of a simplex may be smaller
    simplex[ord[1]], fvalues[ord[1]]
end

end # module

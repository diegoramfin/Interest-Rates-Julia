"""
The zero curve: continuously compounded zero rates by maturity, linear
interpolation between nodes, and the bootstrap method for building the
curve from bond prices (Hull §4.5-§4.6).
"""

"""
    ZeroCurve(times, rates)

Continuously compounded zero rates `rates[i]` for maturities `times[i]`
(years). Between nodes the zero rate is linearly interpolated (Hull's
convention, e.g. the 1.25-year rate in §4.6); outside the nodes the
nearest rate is used (flat extrapolation).
"""
struct ZeroCurve
    times::Vector{Float64}
    rates::Vector{Float64}

    function ZeroCurve(times, rates)
        length(times) == length(rates) ||
            throw(ArgumentError("times and rates must have equal length"))
        !isempty(times) || throw(ArgumentError("curve needs >= 1 point"))
        all(isfinite, rates) ||
            throw(ArgumentError("rates must be finite"))
        all(>(0), times) ||
            throw(ArgumentError("times must be positive"))
        issorted(times) && allunique(times) ||
            throw(ArgumentError("times must be strictly increasing"))
        new(Float64.(collect(times)), Float64.(collect(rates)))
    end
end

Base.length(c::ZeroCurve) = length(c.times)

function Base.show(io::IO, c::ZeroCurve)
    print(io, "ZeroCurve($(length(c)) points, " *
              "T=$(first(c.times))..$(last(c.times))y)")
end

"""
    zero_rate(times, rates, t)

Zero rate at time `t`: linear interpolation between the bracketing nodes,
flat extrapolation outside them.
"""
function zero_rate(times::AbstractVector, rates::AbstractVector, t)
    t <= times[1] && return rates[1]
    t >= times[end] && return rates[end]
    i = searchsortedlast(times, t)
    t1, t2 = times[i], times[i + 1]
    r1, r2 = rates[i], rates[i + 1]
    r1 + (r2 - r1) * (t - t1) / (t2 - t1)
end

zero_rate(c::ZeroCurve, t) = zero_rate(c.times, c.rates, t)

"""
    discount_factor(c, t)

Discount factor `D(t) = exp(-R(t) * t)` with `R(t)` interpolated on `c`.
"""
discount_factor(c::ZeroCurve, t) = exp(-zero_rate(c, t) * t)

"""
    BondQuote(bond, price)

A bond together with its observed market price; input to [`bootstrap`](@ref).
"""
struct BondQuote
    bond::Bond
    price::Float64

    function BondQuote(bond, price)
        price > 0 || throw(ArgumentError("price must be positive"))
        new(bond, Float64(price))
    end
end

"""
    bootstrap(quotes)

Build the zero curve from `quotes` (a collection of `BondQuote`s) via the
bootstrap method (Hull §4.6): instruments are processed in order of
increasing maturity; at each maturity `T` the zero rate solves the bond's
pricing equation, with earlier cash flows discounted off the partial
curve (linearly interpolating through the candidate node `T` itself).
"""
function bootstrap(quotes)
    isempty(quotes) && throw(ArgumentError("no instruments supplied"))
    sorted = sort(collect(quotes); by=q -> q.bond.maturity)
    allunique(q.bond.maturity for q in sorted) ||
        throw(ArgumentError("duplicate instrument maturities"))
    times = Float64[]
    rates = Float64[]
    for q in sorted
        cft, cfa = cashflows(q.bond)
        T = cft[end]
        if length(cft) == 1
            # Zero-coupon instrument: closed form R = -ln(P/F)/T.
            r = -log(q.price / cfa[end]) / T
        else
            # Implied price under the partial curve extended by a trial
            # rate R at T; solve for the R that reprices the bond.
            implied_price(R) = begin
                tt = vcat(times, T)
                rr = vcat(rates, R)
                sum(amt * exp(-zero_rate(tt, rr, t) * t)
                    for (t, amt) in zip(cft, cfa))
            end
            r = solve_decreasing(implied_price, q.price; lo=-0.5, hi=1.0)
        end
        push!(times, T)
        push!(rates, r)
    end
    ZeroCurve(times, rates)
end

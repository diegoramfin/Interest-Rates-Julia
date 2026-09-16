"""
Forward interest rates implied by the term structure, and forward rate
agreement (FRA) valuation (Hull §4.8-§4.9). All rates continuously
compounded.
"""

"""
    forward_rate(r1, t1, r2, t2)

Forward zero rate for the period `[t1, t2]` implied by the `t1` and `t2`
zero rates (Hull eq. 4.5): `R_F = (R2*T2 - R1*T1) / (T2 - T1)`.
"""
function forward_rate(r1, t1, r2, t2)
    t2 > t1 >= 0 || throw(ArgumentError("need 0 <= t1 < t2"))
    (r2 * t2 - r1 * t1) / (t2 - t1)
end

forward_rate(c::ZeroCurve, t1, t2) =
    forward_rate(zero_rate(c, t1), t1, zero_rate(c, t2), t2)

"""
    forward_curve(c)

Forward rates for each interval between adjacent zero-curve nodes,
returned as `(t_start, t_end, rate)` triples. Includes the initial
segment `[0, t1]` at the first zero rate.
"""
function forward_curve(c::ZeroCurve)
    segs = Tuple{Float64,Float64,Float64}[]
    push!(segs, (0.0, c.times[1], c.rates[1]))
    for i in 1:(length(c)-1)
        f = forward_rate(c.rates[i], c.times[i],
                         c.rates[i + 1], c.times[i + 1])
        push!(segs, (c.times[i], c.times[i + 1], f))
    end
    segs
end

"""
    fra_value(L, r_k, r_f, t1, t2, r2)

Value today of a forward rate agreement to the party RECEIVING the fixed
rate `r_k` and paying the floating reference rate, on principal `L`
applied over `[t1, t2]`, when the current forward rate for that period is
`r_f` and the `t2` zero rate is `r2` (Hull §4.9):

    V = L * (r_k - r_f) * (t2 - t1) * exp(-r2 * t2)

The value to the fixed-rate payer is `-V`. An FRA struck at the forward
rate (`r_k == r_f`) is worth zero.
"""
function fra_value(L, r_k, r_f, t1, t2, r2)
    t2 > t1 >= 0 || throw(ArgumentError("need 0 <= t1 < t2"))
    L * (r_k - r_f) * (t2 - t1) * exp(-r2 * t2)
end

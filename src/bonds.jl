"""
Fixed-coupon bonds: cash flows, pricing, yield, par yield, duration,
convexity, and bond-portfolio analytics (Hull ch. 4).

Conventions (Hull-style): times are in years, a bond pays `coupon_rate`
per unit of face per year split into `freq` equal payments, and yields are
continuously compounded unless stated otherwise.
"""

"""
    Bond(face, coupon_rate, freq, maturity)

Plain fixed-coupon bond. `coupon_rate` is the annual coupon per unit of
face (e.g. 0.06), paid `freq` times per year; `maturity` is in years.
"""
struct Bond
    face::Float64
    coupon_rate::Float64
    freq::Int
    maturity::Float64

    function Bond(face, coupon_rate, freq, maturity)
        face > 0 || throw(ArgumentError("face must be positive"))
        coupon_rate >= 0 || throw(ArgumentError("coupon rate must be >= 0"))
        freq >= 1 || throw(ArgumentError("freq must be >= 1"))
        maturity > 0 || throw(ArgumentError("maturity must be positive"))
        new(Float64(face), Float64(coupon_rate), Int(freq), Float64(maturity))
    end
end

Bond(; face=100.0, coupon_rate, freq=2, maturity) =
    Bond(face, coupon_rate, freq, maturity)

function Base.show(io::IO, b::Bond)
    pct = round(100 * b.coupon_rate; sigdigits=6)
    print(io, "Bond(face=$(b.face), coupon=$(pct)% x$(b.freq)/yr, " *
              "T=$(b.maturity)y)")
end

"""
    cashflows(b::Bond) -> (times, amounts)

Cash flow times (years) and amounts. Each coupon equals
`face * coupon_rate / freq`; the final payment also returns the face.
`maturity` must be a whole number of coupon periods.
"""
function cashflows(b::Bond)
    # A zero-coupon bond pays only face at maturity; freq is moot.
    b.coupon_rate == 0 && return ([b.maturity], [b.face])
    n_exact = b.freq * b.maturity
    n = round(Int, n_exact)
    isapprox(n_exact, n; atol=1e-8) || throw(ArgumentError(
        "maturity $(b.maturity)y is not a whole number of " *
        "$(b.freq)x-per-year coupon periods"))
    n >= 1 || throw(ArgumentError("bond has no cash flows"))
    times = [i / b.freq for i in 1:n]
    amounts = fill(b.face * b.coupon_rate / b.freq, n)
    amounts[end] += b.face
    times, amounts
end

"""
    bond_price(times, amounts, curve::ZeroCurve)

Theoretical bond price: each cash flow discounted at the zero rate for
its time (Hull eq. 4.1 / Table 4.2). `curve` is a `ZeroCurve` (declared
in curve.jl, which is included after this file).
"""
bond_price(times, amounts, curve) =
    sum(amt * discount_factor(curve, t) for (t, amt) in zip(times, amounts))

bond_price(b::Bond, curve) =
    bond_price(cashflows(b)..., curve)

"""
    bond_price_at_yield(times, amounts, y)

Present value of the cash flows discounted at a single continuously
compounded yield `y`.
"""
bond_price_at_yield(times, amounts, y) =
    sum(amt * exp(-y * t) for (t, amt) in zip(times, amounts))

bond_price_at_yield(b::Bond, y) =
    bond_price_at_yield(cashflows(b)..., y)

"""
    bond_yield(times, amounts, price)

Continuously compounded yield `y` that makes the present value of the
cash flows equal to `price` (Hull eq. 4.2). Solved by bisection.
"""
function bond_yield(times, amounts, price)
    price > 0 || throw(ArgumentError("price must be positive"))
    solve_decreasing(y -> bond_price_at_yield(times, amounts, y), price)
end

bond_yield(b::Bond, price) =
    bond_yield(cashflows(b)..., price)

"""
    par_yield(curve::ZeroCurve, maturity, freq)

Coupon rate (per unit of face, paid `freq` times per year) that makes a
bond maturing at `maturity` price at par on `curve` (Hull eq. 4.4):

    c = freq * (1 - D(T)) / sum(D(t_i))
"""
function par_yield(curve, maturity, freq)
    n = round(Int, maturity * freq)
    isapprox(maturity * freq, n; atol=1e-8) || throw(ArgumentError(
        "maturity is not a whole number of coupon periods"))
    n >= 1 || throw(ArgumentError("no coupon periods"))
    ds = [discount_factor(curve, i / freq) for i in 1:n]
    freq * (1 - ds[end]) / sum(ds)
end

"""
    macaulay_duration(times, amounts, y)

Macaulay duration `D = sum(t_i * PV_i) / B` with cash flows discounted at
the continuously compounded yield `y` (Hull eq. 4.10). When `y` is
continuous, Macaulay and modified duration coincide.
"""
function macaulay_duration(times, amounts, y)
    B = bond_price_at_yield(times, amounts, y)
    sum(t * amt * exp(-y * t) for (t, amt) in zip(times, amounts)) / B
end

"""
    modified_duration(d_mac, y_m, m)

Modified duration `D* = D / (1 + y_m / m)` for a yield `y_m` expressed
with compounding `m` times per year (Hull eq. 4.13). For a continuously
compounded yield, `D* = D`.
"""
modified_duration(d_mac, y_m, m) = d_mac / (1 + y_m / m)

"""
    convexity(times, amounts, y)

Convexity `C = (1/B) * sum(c_i * t_i^2 * exp(-y * t_i))`, i.e. the
normalized second derivative `B''(y) / B` (Hull §4.11).
"""
function convexity(times, amounts, y)
    B = bond_price_at_yield(times, amounts, y)
    sum(amt * t^2 * exp(-y * t) for (t, amt) in zip(times, amounts)) / B
end

"""
    dollar_duration(B, d_mod)

Dollar duration `D\$ = B * D*`; the price change per unit of yield:
`ΔB = -D\$ * Δy`.
"""
dollar_duration(B, d_mod) = B * d_mod

"""
    pct_change_duration(d_mod, dy)

First-order (duration-only) approximation `ΔB/B = -D* * Δy`
(Hull eq. 4.12).
"""
pct_change_duration(d_mod, dy) = -d_mod * dy

"""
    pct_change_duration_convexity(d_mod, cvx, dy)

Second-order approximation `ΔB/B = -D* * Δy + 0.5 * C * Δy^2`
(Hull eq. 4.14).
"""
pct_change_duration_convexity(d_mod, cvx, dy) =
    -d_mod * dy + 0.5 * cvx * dy^2

"""
    portfolio_metrics(holdings, curve::ZeroCurve)

Price-weighted duration and convexity of a portfolio of bonds
(Hull §4.10). `holdings` is a collection of `(bond, quantity)` pairs.
Returns `(value, duration, convexity, items)` where `items` is a vector
of per-position `(bond, qty, price, yield, duration, convexity, value)`
named tuples. Throws when the net portfolio value is ~zero relative to
the gross exposure (the weighted average is then meaningless).
"""
function portfolio_metrics(holdings, curve)
    value = 0.0
    gross = 0.0
    dsum = 0.0
    csum = 0.0
    items = NamedTuple[]
    for (b, qty) in holdings
        t, a = cashflows(b)
        p = bond_price(t, a, curve)
        y = bond_yield(t, a, p)
        d = macaulay_duration(t, a, y)
        cx = convexity(t, a, y)
        v = qty * p
        value += v
        gross += abs(v)
        dsum += v * d
        csum += v * cx
        push!(items, (bond=b, qty=qty, price=p, yield=y,
                      duration=d, convexity=cx, value=v))
    end
    abs(value) <= eps(Float64) * gross && throw(ArgumentError(
        "portfolio has ~zero net value; duration is undefined"))
    (value=value, duration=dsum / value, convexity=csum / value,
     items=items)
end

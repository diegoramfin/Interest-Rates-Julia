"""
Compounding conventions, discount factors, and root-finding utilities.

All rates are decimals (5% = 0.05). Continuously compounded rates are the
internal hub convention, following Hull ch. 4.
"""

"""
    rate_to_continuous(r_m, m)

Convert a rate `r_m` compounded `m` times per year into the equivalent
continuously compounded rate (Hull eq. 4.3): `R_c = m * log(1 + R_m / m)`.
"""
rate_to_continuous(r_m, m) = m * log1p(r_m / m)

"""
    continuous_to_rate(r_c, m)

Convert a continuously compounded rate `r_c` into the equivalent rate
compounded `m` times per year (Hull eq. 4.4): `R_m = m * (exp(R_c/m) - 1)`.
"""
continuous_to_rate(r_c, m) = m * expm1(r_c / m)

"""
    discount_factor(r, t)

Value today of \$1 received at time `t` under a continuously compounded
zero rate `r`: `D(t) = exp(-r * t)`.
"""
discount_factor(r, t) = exp(-r * t)

"""
    solve_bisection(f, lo, hi; tol=1e-12, maxiter=200)

Return a root of `f` inside `[lo, hi]` by bisection. `f` must take opposite
signs at the two endpoints.
"""
function solve_bisection(f, lo::Real, hi::Real; tol=1e-12, maxiter=200)
    flo = f(lo)
    fhi = f(hi)
    iszero(flo) && return float(lo)
    iszero(fhi) && return float(hi)
    flo * fhi < 0 || throw(ArgumentError(
        "f($lo)=$(flo) and f($hi)=$(fhi) do not bracket a root"))
    a, b, fa = float(lo), float(hi), flo
    for _ in 1:maxiter
        mid = (a + b) / 2
        fmid = f(mid)
        (abs(fmid) < tol || (b - a) / 2 < tol) && return mid
        if sign(fmid) == sign(fa)
            a, fa = mid, fmid
        else
            b = mid
        end
    end
    (a + b) / 2
end

"""
    solve_decreasing(f, target; lo=-0.99, hi=1.0)

Find `x` such that `f(x) == target`, assuming `f` is monotone decreasing
(e.g. a bond's present value as a function of its discount rate). The
initial bracket is expanded until it straddles the solution, then solved
by bisection.
"""
function solve_decreasing(f, target; lo=-0.99, hi=1.0, max_expand=60)
    flo = f(lo) - target
    fhi = f(hi) - target
    n = 0
    while fhi > 0 && n < max_expand
        hi += max(1.0, abs(hi))
        fhi = f(hi) - target
        n += 1
    end
    while flo < 0 && n < max_expand
        lo -= max(1.0, abs(lo))
        flo = f(lo) - target
        n += 1
    end
    flo * fhi <= 0 || throw(ArgumentError(
        "could not bracket the solution; check the input values"))
    solve_bisection(x -> f(x) - target, lo, hi)
end

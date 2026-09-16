# Terminal charts rendered with UnicodePlots.
using UnicodePlots
using Printf

"""
    plot_zero_curve(c)

Zero rate vs maturity (continuously compounded, in %).
"""
function plot_zero_curve(c::ZeroCurve)
    lineplot(c.times, 100 .* c.rates;
             title="Zero curve (continuously compounded)",
             xlabel="maturity (yrs)", ylabel="rate (%)",
             name="zero rate")
end

"""
    plot_zero_and_forward(c)

Zero curve overlaid with the implied forward rates between adjacent
nodes (drawn as a step function).
"""
function plot_zero_and_forward(c::ZeroCurve)
    plt = plot_zero_curve(c)
    xs = Float64[]
    ys = Float64[]
    for (a, b, f) in forward_curve(c)
        append!(xs, (a, b))
        append!(ys, (f, f))
    end
    lineplot!(plt, xs, 100 .* ys; name="forward")
    plt
end

"""
    plot_price_sensitivity(times, amounts, y; span=0.05, npts=61)

Percentage price change vs a parallel yield shift `Δy`: the exact
repricing curve against the duration-only and duration+convexity
approximations (Hull eq. 4.12 vs 4.14). The widening gap between the
lines is the convexity effect.
"""
function plot_price_sensitivity(times, amounts, y; span=0.05, npts=61)
    B = bond_price_at_yield(times, amounts, y)
    D = macaulay_duration(times, amounts, y)
    C = convexity(times, amounts, y)
    dys = collect(range(-span, span; length=npts))
    xs = 100 .* dys
    exact = [100 * (bond_price_at_yield(times, amounts, y + dy) - B) / B
             for dy in dys]
    dur = [100 * pct_change_duration(D, dy) for dy in dys]
    dcv = [100 * pct_change_duration_convexity(D, C, dy) for dy in dys]
    plt = lineplot(xs, exact;
                   title="Bond price vs parallel yield shift",
                   xlabel="Δy (percentage pts)", ylabel="ΔB/B (%)",
                   name="exact")
    lineplot!(plt, xs, dur; name="duration")
    lineplot!(plt, xs, dcv; name="dur+convex")
    plt
end

"""
    plot_cashflows(times, pvs)

Horizontal bar chart of the present value of each cash flow.
"""
function plot_cashflows(times, pvs)
    labels = [@sprintf("%.2f", t) for t in times]
    barplot(labels, pvs;
            title="PV of cash flows by time (yrs)", xlabel="PV")
end

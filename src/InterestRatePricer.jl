"""
Interactive interest-rate pricer built on Hull's *Options, Futures, and
Other Derivatives*, ch. 4: compounding conversions, the zero curve
(bootstrap), bond pricing / yield / par yield, forward rates, FRAs,
duration, convexity, and bond-portfolio metrics — driven by a REPL menu
with UnicodePlots charts.

Run with: `julia --project=. main.jl`
"""
module InterestRatePricer

include("rates.jl")
include("bonds.jl")
include("curve.jl")
include("forwards.jl")
include("plots.jl")
include("tui.jl")

export Bond, BondQuote, ZeroCurve,
    cashflows, bond_price, bond_price_at_yield, bond_yield, par_yield,
    macaulay_duration, modified_duration, dollar_duration, convexity,
    pct_change_duration, pct_change_duration_convexity, portfolio_metrics,
    bootstrap, zero_rate, discount_factor,
    forward_rate, forward_curve, fra_value,
    rate_to_continuous, continuous_to_rate,
    solve_bisection, solve_decreasing,
    plot_zero_curve, plot_zero_and_forward, plot_price_sensitivity,
    plot_cashflows, main

end

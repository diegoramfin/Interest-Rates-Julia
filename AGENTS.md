# Interest Rate Pricer (Julia)

Interactive REPL pricer for Hull *Options, Futures, and Other
Derivatives*, ch. 4: rate conversions, zero-curve bootstrap, bond
price/yield/par yield, forward rates, FRA valuation, duration,
convexity, bond portfolios, and terminal plots (UnicodePlots).

## Conventions

- Rates are decimals internally; the TUI prompts in %.
- Zero rates and yields are continuously compounded
  (`rate_to_continuous` / `continuous_to_rate` convert).
- Hull-style bonds: times in years, `freq` equal coupons per year,
  maturity must be a whole number of coupon periods. No day counts.
- Zero curve: linear interpolation on rates between nodes, flat
  extrapolation outside (Hull §4.6 convention).

## Commands

```bash
julia --project=. main.jl            # run the TUI
julia --project=. test/runtests.jl   # run the test suite
```

## Layout

- `src/rates.jl`    — compounding conversions, discount factors, solvers
- `src/bonds.jl`    — `Bond`, cashflows, price/yield/par yield,
  duration, convexity, `portfolio_metrics`
- `src/curve.jl`    — `ZeroCurve`, interpolation, `bootstrap`, `BondQuote`
- `src/forwards.jl` — forward rates, `forward_curve`, `fra_value`
- `src/plots.jl`    — UnicodePlots charts (zero+forward curve,
  price-sensitivity, cash-flow PVs)
- `src/tui.jl`      — REPL menu loop and prompt helpers
- `main.jl`         — entry point
- `test/runtests.jl`— Hull worked examples as fixtures

## Testing notes

Fixtures are Hull ch. 4 worked examples: Table 4.2 price (98.39),
yield 6.76%, par yield 6.87%, Table 4.3 bootstrap rates
(1.603/2.010/2.225/2.284/2.416%), Table 4.5 forwards
(5.0/5.8/6.2/6.5%), Table 4.6 duration (B=94.213, D=2.653, C=7.570).

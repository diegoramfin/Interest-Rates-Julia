# Interest Rate Pricer

Interactive Julia TUI implementing the fixed-income toolkit from Hull,
*Options, Futures, and Other Derivatives*, chapter 4: rate conversions,
zero-curve bootstrap, bond pricing/yield/par yield, forward rates, FRA
valuation, duration/convexity analytics, bond portfolios, and terminal
plots via UnicodePlots.

## Install & run

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'   # one-time: install deps
julia --project=. main.jl                            # launch the TUI
```

Requires Julia 1.x (tested on 1.12.6); sole dependency is `UnicodePlots`.

## What it does

| # | Action | Hull ref |
|---|--------|----------|
| 1 | Convert rate (m-times ↔ continuous ↔ other m) | eq. 4.3–4.4 |
| 2 | Set zero curve manually | §4.5 |
| 3 | Bootstrap zero curve from bond prices | §4.6, Table 4.3 |
| 4 | Show zero curve + plot (with forward curve) | Fig. 4.1 |
| 5 | Price a bond from the zero curve | Table 4.2 |
| 6 | Bond yield from market price | eq. 4.2 |
| 7 | Par yield for a maturity | §4.4 |
| 8 | Forward rate for [T1, T2] | eq. 4.5, Table 4.5 |
| 9 | Value a FRA (receiver & payer) | §4.9 |
| 10 | Duration, convexity, ΔB approximations, plots | §4.10–4.11 |
| 11 | Bond portfolio duration & convexity | §4.10 |

Conventions: rates are entered in **%**, zero rates and yields are
**continuously compounded**, times are in years, and the session zero
curve is reused across options after a confirmation prompt.

See [QUICKSTART.md](QUICKSTART.md) for a full worked example
(reproducing Hull Table 4.3's bootstrap end-to-end) and
[AGENTS.md](AGENTS.md) for module layout and conventions.

## Testing

```bash
julia --project=. test/runtests.jl
```

48 tests, all fixtures drawn from Hull ch. 4 worked examples
(Tables 4.2/4.3/4.5/4.6, FRA valuation, duration/convexity).

## Layout

```
main.jl                    entry point
src/InterestRatePricer.jl  module root
src/rates.jl               compounding conversions, discount factors
src/bonds.jl               Bond, cashflows, price/yield, duration, convexity
src/curve.jl               ZeroCurve, interpolation, bootstrap
src/forwards.jl            forward rates, FRA valuation
src/plots.jl               UnicodePlots charts
src/tui.jl                 REPL menu loop
test/runtests.jl           Hull worked-example fixtures
```

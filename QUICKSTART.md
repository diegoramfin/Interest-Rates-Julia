# Quick Start — Interest Rate Pricer

Interactive Julia TUI for Hull *Options, Futures, and Other
Derivatives*, chapter 4: rate conversions, zero-curve bootstrap, bond
pricing/yield/par yield, forward rates, FRA valuation, duration,
convexity, and bond portfolios.

## Requirements

- Julia (built/tested on 1.12.6; any recent 1.x works).
  Install via [juliaup](https://github.com/JuliaLang/juliaup) if needed.
- One dependency: `UnicodePlots` (plus stdlib `Printf`). Both are
  pinned in `Manifest.toml`.

## Setup

From the project directory:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'   # install deps
julia --project=. main.jl                            # launch the TUI
```

## Conventions

- Rates are **typed in %** (enter `5`, not `0.05`) and converted to
  decimals internally.
- Zero rates and bond yields are **continuously compounded**;
  conversions to/from periodic compounding are menu option 1.
- Maturities/times are in **years**; coupons pay `freq` times per year.
- Prompts show defaults in `[brackets]` — press Enter to accept.
- `q`, `b`, `quit`, or `back` cancels any prompt and returns to the
  menu; `q` at the menu (or Ctrl-D) exits.

## Menu

| # | Action | Hull ref |
|---|--------|----------|
| 1 | Convert rate (m-times ↔ continuous ↔ other m) | eq. 4.3–4.4 |
| 2 | Set zero curve manually | §4.5 |
| 3 | Bootstrap zero curve from bond prices | §4.6, Table 4.3 |
| 4 | Show current zero curve + plot (with forward curve) | Fig. 4.1 |
| 5 | Price a bond from the zero curve (cash-flow table) | Table 4.2 |
| 6 | Bond yield from market price (cont. + equivalent periodic) | eq. 4.2 |
| 7 | Par yield for a maturity | §4.4 |
| 8 | Forward rate for [T1, T2] | eq. 4.5, Table 4.5 |
| 9 | Value a FRA (receiver & payer) | §4.9 |
| 10 | Bond analytics: duration, convexity, ΔB approximations, plots | §4.10–4.11 |
| 11 | Bond portfolio duration & convexity | §4.10 |

The zero curve you enter (option 2) or bootstrap (option 3) is kept for
the session — options 5, 7, 8, 9, 10, 11 offer to reuse it, each with
its own confirmation (`use this curve?`, `imply the forward from the
current curve?`, `price the bond from the current curve?`, …).

## Worked example (Hull Table 4.3 bootstrap)

Reproduce the textbook zero curve — 3-month/6-month/1-year zero-coupon
bonds at 99.6/99.0/97.8, a 1.5y 4% bond at 102.5, and a 2y 5% bond at
105.0 (coupons semiannual, face 100):

```
choice> 3
  number of instruments: 5
  instrument 1:
  maturity (years): 0.25
  annual coupon rate (in %) [0.0]:      <- Enter
  face [100.0]:                          <- Enter
  market price: 99.6
  instrument 2:  maturity 0.5,  coupon <Enter>, face <Enter>, price 99.0
  instrument 3:  maturity 1,    coupon <Enter>, face <Enter>, price 97.8
  instrument 4:  maturity 1.5,  coupon 4, coupons/yr <Enter>, face <Enter>, price 102.5
  instrument 5:  maturity 2,    coupon 5, coupons/yr <Enter>, face <Enter>, price 105
```

Result (matches Hull): `1.603% 2.010% 2.225% 2.284% 2.416%`
continuously compounded — then answer `y` to see the zero + forward
curve plot.

Now price a bond on it (option `5`, accept the curve with Enter,
e.g. coupon `6`, `x2/yr`, maturity `2`), or run analytics on the
Table 4.6 bond (option `10`: coupon `10`, `x2/yr`, maturity `3`, answer
`n` to curve pricing and enter market price `94.213` → yields 12% cont,
duration 2.653, convexity 7.570).

## Tests

```bash
julia --project=. test/runtests.jl
```

All fixtures are Hull ch. 4 worked examples — see `test/runtests.jl`
for ready-made input data. Conventions and module layout are documented
in `AGENTS.md`.

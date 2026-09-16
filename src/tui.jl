# Interactive REPL menu driving the pricer.
using Printf

mutable struct AppState
    curve::Union{ZeroCurve,Nothing}
end

# ---------------- input helpers ----------------

# Reads a stripped line; returns `nothing` at EOF (Ctrl-D / closed
# stdin) so callers can treat end-of-input as quit.
function _read_raw()
    eof(stdin) && return nothing
    strip(readline())
end

# Returns the stripped line, or `nothing` when the user asks to
# cancel/go back or stdin hits EOF. An empty line is returned as ""
# (callers decide whether that means "use default" or "cancel").
function _input(msg)
    print(msg)
    s = _read_raw()
    s === nothing && return nothing
    lowercase(s) in ("q", "quit", "b", "back") && return nothing
    s
end

function prompt_float(msg; default=nothing, check=isfinite,
                      errmsg="invalid number")
    while true
        s = _input(default === nothing ? "  $msg: " :
                   "  $msg [$default]: ")
        s === nothing && return nothing
        isempty(s) && return default
        x = tryparse(Float64, s)
        x !== nothing && check(x) && return x
        println("  ! $errmsg — try again (or 'q' to cancel)")
    end
end

function prompt_int(msg; default=nothing, check=x -> true,
                    errmsg="invalid integer")
    while true
        s = _input(default === nothing ? "  $msg: " :
                   "  $msg [$default]: ")
        s === nothing && return nothing
        isempty(s) && return default
        x = tryparse(Int, s)
        x !== nothing && check(x) && return x
        println("  ! $errmsg — try again (or 'q' to cancel)")
    end
end

"""Prompt for a rate typed in percent; returns a decimal."""
function prompt_rate_pct(msg; default_pct=nothing)
    x = prompt_float("$msg (in %)"; default=default_pct)
    x === nothing && return nothing
    x / 100
end

function yes_no(msg; default=true)
    s = _input("  $msg " * (default ? "[Y/n]: " : "[y/N]: "))
    s === nothing && return false   # 'q'/'b'/EOF never answer "yes"
    isempty(s) && return default
    lowercase(s) in ("y", "yes")
end

_pause() = (print("  <enter> "); _read_raw())

# ---------------- shared prompts / output ----------------

function prompt_curve()
    n = prompt_int("number of curve points"; check=x -> x >= 1,
                   errmsg="need >= 1")
    n === nothing && return nothing
    times = Float64[]
    rates = Float64[]
    for i in 1:n
        t = prompt_float("maturity T$i (years)"; check=x -> x > 0,
                         errmsg="must be > 0")
        t === nothing && return nothing
        r = prompt_rate_pct("zero rate at T$i (cont.)")
        r === nothing && return nothing
        push!(times, t)
        push!(rates, r)
    end
    p = sortperm(times)
    ZeroCurve(times[p], rates[p])
end

function prompt_bond()
    face = prompt_float("face value"; default=100.0, check=x -> x > 0,
                        errmsg="must be > 0")
    face === nothing && return nothing
    cpn = prompt_rate_pct("annual coupon rate"; default_pct=0.0)
    cpn === nothing && return nothing
    freq = 1
    if cpn > 0
        f = prompt_int("coupons per year"; default=2,
                       check=x -> x >= 1, errmsg="must be >= 1")
        f === nothing && return nothing
        freq = f
    end
    T = prompt_float("maturity (years)"; check=x -> x > 0,
                     errmsg="must be > 0")
    T === nothing && return nothing
    Bond(face, cpn, freq, T)
end

function print_curve(c::ZeroCurve)
    println("    T (yrs)   zero % (cont)    D(T)")
    for (t, r) in zip(c.times, c.rates)
        @printf("    %7.3f      %9.4f    %8.5f\n",
                t, 100 * r, discount_factor(c, t))
    end
end

function print_cashflow_table(times, amounts, dfs)
    println("     t (yrs)   cash flow      D(t)          PV")
    for (t, cf, d) in zip(times, amounts, dfs)
        @printf("     %6.2f   %10.4f   %8.5f   %10.4f\n",
                t, cf, d, cf * d)
    end
    @printf("     %-28s total = %.4f\n", "", sum(amounts .* dfs))
end

"""
Return the session zero curve, letting the user confirm, replace, or
enter one when none exists. Stores any newly entered curve.
"""
function ensure_curve(state)
    if state.curve !== nothing
        print_curve(state.curve)
        yes_no("use this curve?"; default=true) && return state.curve
    end
    println("  enter the zero curve (continuously compounded):")
    c = prompt_curve()
    c === nothing && return nothing
    state.curve = c
    c
end

# ---------------- menu actions ----------------

function action_convert(::AppState)
    println("  1) m-times-per-year  ->  continuous")
    println("  2) continuous        ->  m-times-per-year")
    println("  3) m1-times-per-year ->  m2-times-per-year")
    s = _input("  direction> ")
    s === nothing && return
    if s == "1"
        r = prompt_rate_pct("rate");       r === nothing && return
        m = prompt_int("compounds / year"; check=x -> x >= 1)
        m === nothing && return
        r <= -m && (println("  ! rate must be > $(-100m)%"); return)
        @printf("  %.4f%% x%d/yr -> %.4f%% continuous\n",
                100r, m, 100 * rate_to_continuous(r, m))
    elseif s == "2"
        r = prompt_rate_pct("rate (cont.)"); r === nothing && return
        m = prompt_int("compounds / year"; check=x -> x >= 1)
        m === nothing && return
        @printf("  %.4f%% cont -> %.4f%% x%d/yr\n",
                100r, 100 * continuous_to_rate(r, m), m)
    elseif s == "3"
        r = prompt_rate_pct("rate");        r === nothing && return
        m1 = prompt_int("from compounds / year"; check=x -> x >= 1)
        m1 === nothing && return
        r <= -m1 && (println("  ! rate must be > $(-100m1)%"); return)
        m2 = prompt_int("to compounds / year"; check=x -> x >= 1)
        m2 === nothing && return
        out = continuous_to_rate(rate_to_continuous(r, m1), m2)
        @printf("  %.4f%% x%d/yr -> %.4f%% x%d/yr\n", 100r, m1, 100out, m2)
    else
        println("  ? unknown direction")
    end
end

function action_set_curve(state)
    c = prompt_curve()
    c === nothing && return
    state.curve = c
    println("  curve set:")
    print_curve(c)
end

function action_bootstrap(state)
    n = prompt_int("number of instruments"; check=x -> x >= 1)
    n === nothing && return
    quotes = BondQuote[]
    for i in 1:n
        println("  instrument $i:")
        T = prompt_float("maturity (years)"; check=x -> x > 0)
        T === nothing && return
        cpn = prompt_rate_pct("annual coupon rate"; default_pct=0.0)
        cpn === nothing && return
        freq = 1
        if cpn > 0
            f = prompt_int("coupons per year"; default=2,
                           check=x -> x >= 1)
            f === nothing && return
            freq = f
        end
        face = prompt_float("face"; default=100.0, check=x -> x > 0)
        face === nothing && return
        px = prompt_float("market price"; check=x -> x > 0)
        px === nothing && return
        push!(quotes, BondQuote(Bond(face, cpn, freq, T), px))
    end
    c = bootstrap(quotes)
    state.curve = c
    println("  bootstrapped zero curve (continuous compounding):")
    print_curve(c)
    yes_no("plot zero + forward curve?"; default=true) &&
        display(plot_zero_and_forward(c))
end

function action_show_curve(state)
    if state.curve === nothing
        println("  no curve set — use option 2 or 3 first")
        return
    end
    print_curve(state.curve)
    yes_no("plot zero + forward curve?"; default=true) &&
        display(plot_zero_and_forward(state.curve))
end

function action_price_bond(state)
    c = ensure_curve(state)
    c === nothing && return
    b = prompt_bond()
    b === nothing && return
    t, a = cashflows(b)
    dfs = [discount_factor(c, ti) for ti in t]
    print_cashflow_table(t, a, dfs)
    price = bond_price(t, a, c)
    @printf("  bond price            = %.4f\n", price)
    @printf("  implied yield (cont.) = %.4f%%\n",
            100 * bond_yield(t, a, price))
end

function action_yield(::AppState)
    b = prompt_bond()
    b === nothing && return
    px = prompt_float("market price"; check=x -> x > 0)
    px === nothing && return
    t, a = cashflows(b)
    y = bond_yield(t, a, px)
    @printf("  bond yield = %.4f%% continuous\n", 100y)
    @printf("             = %.4f%% with %dx-per-year compounding\n",
            100 * continuous_to_rate(y, b.freq), b.freq)
end

function action_par_yield(state)
    c = ensure_curve(state)
    c === nothing && return
    T = prompt_float("maturity (years)"; check=x -> x > 0)
    T === nothing && return
    m = prompt_int("coupons per year"; default=2, check=x -> x >= 1)
    m === nothing && return
    cpn = par_yield(c, T, m)
    @printf("  %g-year par yield = %.4f%% per annum (paid x%d/yr)\n",
            T, 100cpn, m)
end

function action_forward(state)
    if state.curve !== nothing &&
       yes_no("read zero rates from the current curve?"; default=true)
        c = state.curve
        t1 = prompt_float("T1 (years)"; check=x -> x >= 0)
        t1 === nothing && return
        t2 = prompt_float("T2 (years)"; check=x -> x > t1)
        t2 === nothing && return
        r1 = zero_rate(c, t1)
        r2 = zero_rate(c, t2)
        @printf("  R1 = %.4f%%,  R2 = %.4f%%\n", 100r1, 100r2)
    else
        r1 = prompt_rate_pct("R1 (cont.)"); r1 === nothing && return
        t1 = prompt_float("T1 (years)"; check=x -> x >= 0)
        t1 === nothing && return
        r2 = prompt_rate_pct("R2 (cont.)"); r2 === nothing && return
        t2 = prompt_float("T2 (years)"; check=x -> x > t1)
        t2 === nothing && return
    end
    f = forward_rate(r1, t1, r2, t2)
    @printf("  forward rate over [%.3f, %.3f] = %.4f%% (cont.)\n",
            t1, t2, 100f)
end

function action_fra(state)
    println("  FRA: exchange fixed R_K for the reference rate on L" *
            " over [T1, T2].")
    t1 = prompt_float("T1 — period start (years)"; check=x -> x >= 0)
    t1 === nothing && return
    t2 = prompt_float("T2 — period end (years)"; check=x -> x > t1)
    t2 === nothing && return
    L = prompt_float("principal L"; default=1_000_000.0,
                     check=x -> x > 0)
    L === nothing && return
    rk = prompt_rate_pct("fixed rate R_K")
    rk === nothing && return
    if state.curve !== nothing &&
       yes_no("imply the forward from the current curve?"; default=true)
        c = state.curve
        rf = forward_rate(c, t1, t2)
        r2 = zero_rate(c, t2)
        @printf("  implied R_F = %.4f%%,  R2 = %.4f%%\n", 100rf, 100r2)
    else
        rf = prompt_rate_pct("forward rate R_F (cont.)")
        rf === nothing && return
        r2 = prompt_rate_pct("T2 zero rate (cont.)")
        r2 === nothing && return
    end
    v = fra_value(L, rk, rf, t1, t2, r2)
    @printf("  value to fixed-rate RECEIVER = %+.2f\n", v)
    @printf("  value to fixed-rate PAYER    = %+.2f\n", -v)
end

function action_analytics(state)
    b = prompt_bond()
    b === nothing && return
    t, a = cashflows(b)
    if state.curve !== nothing &&
       yes_no("price the bond from the current curve?"; default=true)
        dfs = [discount_factor(state.curve, ti) for ti in t]
        print_cashflow_table(t, a, dfs)
        price = sum(a .* dfs)
    else
        price = prompt_float("market price"; check=x -> x > 0)
        price === nothing && return
    end
    y = bond_yield(t, a, price)
    D = macaulay_duration(t, a, y)
    C = convexity(t, a, y)
    ym = continuous_to_rate(y, b.freq)
    Dstar = modified_duration(D, ym, b.freq)
    @printf("  price = %.4f   yield = %.4f%% cont (%.4f%% x%d/yr)\n",
            price, 100y, 100ym, b.freq)
    println("     t (yrs)      PV      weight   t*weight   t^2*weight")
    for (ti, ai) in zip(t, a)
        pv = ai * exp(-y * ti)
        w = pv / price
        @printf("     %6.2f  %9.4f   %7.4f   %8.4f   %9.4f\n",
                ti, pv, w, ti * w, ti^2 * w)
    end
    @printf("  Macaulay duration = %.4f yrs\n", D)
    @printf("  modified duration = %.4f (x%d/yr yield)\n", Dstar, b.freq)
    @printf("  dollar duration   = %.4f\n", dollar_duration(price, Dstar))
    @printf("  convexity         = %.4f\n", C)
    dy_pct = prompt_float("yield shift Δy (in %)";
                          default=0.1, check=isfinite)
    dy_pct === nothing && return
    dy = dy_pct / 100
    exact = (bond_price_at_yield(t, a, y + dy) - price) / price
    @printf("  ΔB/B exact reprice      = %+.4f%%\n", 100 * exact)
    @printf("  ΔB/B duration only      = %+.4f%%\n",
            100 * pct_change_duration(D, dy))
    @printf("  ΔB/B duration+convexity = %+.4f%%\n",
            100 * pct_change_duration_convexity(D, C, dy))
    yes_no("plot price vs yield shift?"; default=true) &&
        display(plot_price_sensitivity(t, a, y))
    yes_no("plot PV of cash flows?"; default=false) &&
        display(plot_cashflows(t, [ai * exp(-y * ti)
                                   for (ti, ai) in zip(t, a)]))
end

function action_portfolio(state)
    c = ensure_curve(state)
    c === nothing && return
    n = prompt_int("number of positions"; check=x -> x >= 1)
    n === nothing && return
    holdings = Tuple{Bond,Float64}[]
    for i in 1:n
        println("  position $i —")
        b = prompt_bond()
        b === nothing && return
        q = prompt_float("quantity (+ long, - short)"; default=1.0)
        q === nothing && return
        push!(holdings, (b, q))
    end
    m = portfolio_metrics(holdings, c)
    println("    position                              price      " *
            "yield%     dur      convex     weight")
    for it in m.items
        @printf("    %-38s %8.3f   %7.4f   %7.4f   %8.4f   %8.4f\n",
                string(it.bond), it.price, 100 * it.yield,
                it.duration, it.convexity, it.value / m.value)
    end
    @printf("  portfolio value = %.2f   duration = %.4f   convexity = %.4f\n",
            m.value, m.duration, m.convexity)
    @printf("  DV01 (+1bp parallel shift) = %.2f\n",
            m.value * m.duration * 1e-4)
end

# ---------------- main loop ----------------

const MENU = """
    ---- interest rate pricer (Hull ch. 4) ----
     1) convert rate (compounding)
     2) set zero curve manually
     3) bootstrap zero curve from bonds
     4) show current zero curve (+ plot)
     5) price a bond (from zero curve)
     6) bond yield (from market price)
     7) par yield
     8) forward rate
     9) value a FRA
    10) bond analytics (duration & convexity)
    11) bond portfolio (duration & convexity)
     q) quit
    """

function main()
    state = AppState(nothing)
    println("\n== interest rate pricer — Hull ch. 4 ==")
    println("   rates are entered in %; zero rates and yields are")
    println("   continuously compounded. 'q' cancels any prompt.\n")
    while true
        println(MENU)
        print("   curve: ")
        println(state.curve === nothing ? "none" :
                "$(length(state.curve)) points")
        s = _input("   choice> ")
        s === nothing && break
        isempty(s) && continue
        println()
        try
            if     s == "1";  action_convert(state)
            elseif s == "2";  action_set_curve(state)
            elseif s == "3";  action_bootstrap(state)
            elseif s == "4";  action_show_curve(state)
            elseif s == "5";  action_price_bond(state)
            elseif s == "6";  action_yield(state)
            elseif s == "7";  action_par_yield(state)
            elseif s == "8";  action_forward(state)
            elseif s == "9";  action_fra(state)
            elseif s == "10"; action_analytics(state)
            elseif s == "11"; action_portfolio(state)
            else; println("  ? unknown option")
            end
        catch e
            println("  ! ", sprint(showerror, e))
        end
        println()
        _pause()
        println()
    end
    println("bye")
    nothing
end

using InterestRatePricer
using Test

@testset "compounding conversions" begin
    # Hull p.83 examples: 10% semiannual -> 9.758% continuous;
    # 8% continuous -> 8.08% quarterly.
    @test rate_to_continuous(0.10, 2) ≈ 0.09758 atol = 1e-5
    @test continuous_to_rate(0.08, 4) ≈ 0.0808 atol = 1e-4
    # round trip through the continuous hub
    @test continuous_to_rate(rate_to_continuous(0.06, 12), 12) ≈ 0.06 atol = 1e-12
    @test rate_to_continuous(continuous_to_rate(0.05, 4), 4) ≈ 0.05 atol = 1e-12
end

@testset "bond pricing (Table 4.2)" begin
    # 2y bond, 6% semiannual coupon, on the 5.0/5.8/6.4/6.8 zero curve.
    c = ZeroCurve([0.5, 1.0, 1.5, 2.0], [0.05, 0.058, 0.064, 0.068])
    b = Bond(100.0, 0.06, 2, 2.0)
    t, a = cashflows(b)
    @test t == [0.5, 1.0, 1.5, 2.0]
    @test a == [3.0, 3.0, 3.0, 103.0]
    @test bond_price(t, a, c) ≈ 98.39 atol = 5e-3
    @test bond_price(b, c) ≈ 98.39 atol = 5e-3
end

@testset "bond yield" begin
    # Hull: the yield solving the Table 4.2 bond at price 98.39 is 6.76%.
    t, a = cashflows(Bond(100.0, 0.06, 2, 2.0))
    @test bond_yield(t, a, 98.39) ≈ 0.0676 atol = 5e-4
    # consistency: yield reprices to the input price
    p = bond_price_at_yield(t, a, 0.05)
    @test bond_yield(t, a, p) ≈ 0.05 atol = 1e-10
end

@testset "par yield" begin
    # Hull §4.4: 2-year par yield on the Table 4.2 curve is 6.87%.
    c = ZeroCurve([0.5, 1.0, 1.5, 2.0], [0.05, 0.058, 0.064, 0.068])
    @test par_yield(c, 2.0, 2) ≈ 0.0687 atol = 1e-4
    # a bond issued at the par yield prices at par
    cpn = par_yield(c, 2.0, 2)
    @test bond_price(Bond(100.0, cpn, 2, 2.0), c) ≈ 100.0 atol = 1e-10
end

@testset "bootstrap (Table 4.3)" begin
    quotes = [
        BondQuote(Bond(100.0, 0.0, 2, 0.25), 99.6),
        BondQuote(Bond(100.0, 0.0, 2, 0.50), 99.0),
        BondQuote(Bond(100.0, 0.0, 2, 1.00), 97.8),
        BondQuote(Bond(100.0, 0.04, 2, 1.50), 102.5),
        BondQuote(Bond(100.0, 0.05, 2, 2.00), 105.0),
    ]
    c = bootstrap(quotes)
    @test c.times == [0.25, 0.5, 1.0, 1.5, 2.0]
    @test c.rates[1] ≈ 0.01603 atol = 5e-5   # 1.603%
    @test c.rates[2] ≈ 0.02010 atol = 5e-5   # 2.010%
    @test c.rates[3] ≈ 0.02225 atol = 5e-5   # 2.225%
    @test c.rates[4] ≈ 0.02284 atol = 5e-5   # 2.284%
    @test c.rates[5] ≈ 0.02416 atol = 5e-5   # 2.416%
    # Hull's linear interpolation: the 1.25y rate is 2.255%.
    @test zero_rate(c, 1.25) ≈ 0.02255 atol = 1e-5
    # every input bond reprices to its quoted price
    for q in quotes
        @test bond_price(q.bond, c) ≈ q.price atol = 1e-8
    end
end

@testset "forward rates (Table 4.5)" begin
    c = ZeroCurve([1.0, 2.0, 3.0, 4.0, 5.0],
                  [0.030, 0.040, 0.046, 0.050, 0.053])
    segs = forward_curve(c)
    @test [s[3] for s in segs] ≈ [0.030, 0.050, 0.058, 0.062, 0.065] atol = 1e-9
    @test forward_rate(0.046, 3.0, 0.05, 4.0) ≈ 0.062 atol = 1e-12
end

@testset "FRA valuation" begin
    # An FRA struck at the forward rate is worth zero.
    @test fra_value(1e6, 0.05, 0.05, 2.0, 2.25, 0.04) == 0.0
    # Receiver of fixed profits when R_K > R_F; payer gets the negative.
    v = fra_value(1e8, 0.03, 0.035, 2.0, 2.25, 0.04)
    @test v ≈ 1e8 * (0.03 - 0.035) * 0.25 * exp(-0.04 * 2.25) atol = 1e-6
    @test v < 0
    # Hull §4.9 settlement example through the production function:
    # receiving fixed 3% while the realized/forward rate is 3.5% on
    # \$100mm over a quarter loses 125,000 at T2 (zero discounting).
    @test fra_value(1e8, 0.03, 0.035, 2.0, 2.25, 0.0) ≈ -125_000 atol = 1e-6
end

@testset "duration & convexity (Table 4.6, Ex. 4.4/4.5)" begin
    # 3y bond, 10% semiannual coupon, y = 12% continuous.
    b = Bond(100.0, 0.10, 2, 3.0)
    t, a = cashflows(b)
    B = bond_price_at_yield(t, a, 0.12)
    @test B ≈ 94.213 atol = 5e-3
    D = macaulay_duration(t, a, 0.12)
    @test D ≈ 2.653 atol = 5e-3
    C = convexity(t, a, 0.12)
    @test C ≈ 7.570 atol = 1e-2
    # modified duration for the equivalent semiannual yield (12.3673%)
    y2 = continuous_to_rate(0.12, 2)
    @test y2 ≈ 0.123673 atol = 1e-6
    @test modified_duration(D, y2, 2) ≈ 2.499 atol = 5e-3
    # Ex. 4.4: +10bp -> duration approx predicts 93.963, matching reprice.
    @test B + B * pct_change_duration(D, 0.001) ≈ 93.963 atol = 1e-3
    @test bond_price_at_yield(t, a, 0.121) ≈ 93.963 atol = 1e-3
    # for a 200bp shift, adding convexity is far more accurate
    dy = 0.02
    exact = (bond_price_at_yield(t, a, 0.12 + dy) - B) / B
    e_dur = abs(exact - pct_change_duration(D, dy))
    e_dcv = abs(exact - pct_change_duration_convexity(D, C, dy))
    @test e_dcv < 0.1 * e_dur
end

@testset "portfolio metrics" begin
    c = ZeroCurve([0.5, 1.0, 1.5, 2.0], [0.05, 0.058, 0.064, 0.068])
    b1 = Bond(100.0, 0.06, 2, 2.0)
    b2 = Bond(100.0, 0.0, 2, 0.5)
    m = portfolio_metrics([(b1, 1.0), (b2, 2.0)], c)
    # duration of a zero-coupon bond equals its maturity
    t2, a2 = cashflows(b2)
    d2 = macaulay_duration(t2, a2, bond_yield(t2, a2, bond_price(b2, c)))
    @test d2 ≈ 0.5 atol = 1e-10
    # portfolio duration is the value-weighted average
    p1, p2 = bond_price(b1, c), bond_price(b2, c)
    t1, a1 = cashflows(b1)
    d1 = macaulay_duration(t1, a1, bond_yield(t1, a1, p1))
    @test m.value ≈ p1 + 2p2 atol = 1e-10
    @test m.duration ≈ (p1 * d1 + 2p2 * d2) / (p1 + 2p2) atol = 1e-10
end

@testset "edge cases" begin
    @test_throws ArgumentError Bond(100.0, 0.05, 2, 0.0)
    @test_throws ArgumentError Bond(-100.0, 0.05, 2, 1.0)
    @test_throws ArgumentError ZeroCurve([1.0, 1.0], [0.01, 0.02])
    @test_throws ArgumentError cashflows(Bond(100.0, 0.05, 2, 1.3))
    # flat extrapolation beyond the nodes
    c = ZeroCurve([1.0, 2.0], [0.03, 0.04])
    @test zero_rate(c, 0.25) == 0.03
    @test zero_rate(c, 5.0) == 0.04
    # negative yields are allowed
    t, a = cashflows(Bond(100.0, 0.0, 1, 1.0))
    @test bond_yield(t, a, 102.0) < 0
end

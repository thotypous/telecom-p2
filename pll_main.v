/**
 * PLL configuration
 *
 * This Verilog module was generated automatically
 * using the gowin-pll tool.
 * Use at your own risk.
 *
 * Target-Device:                GW1NR-9 C6/I5
 * Given input frequency:        27.000 MHz
 * Requested output frequency:   65.536 MHz
 * Achieved output frequency:    65.571 MHz
 */

module pll_main(
        input  clock_in,
        output clock_out,
        output locked
    );

    rPLL #(
        .FCLKIN("27"),
        .IDIV_SEL(6), // -> PFD = 3.857142857142857 MHz (range: 3-400 MHz)
        .FBDIV_SEL(16), // -> CLKOUT = 65.57142857142857 MHz (range: 400-600 MHz)
        .ODIV_SEL(8) // -> VCO = 524.5714285714286 MHz (range: 600-1200 MHz)
    ) pll (.CLKOUTP(), .CLKOUTD(), .CLKOUTD3(), .RESET(1'b0), .RESET_P(1'b0), .CLKFB(1'b0), .FBDSEL(6'b0), .IDSEL(6'b0), .ODSEL(6'b0), .PSDA(4'b0), .DUTYDA(4'b0), .FDLY(4'b0), 
        .CLKIN(clock_in), // 27 MHz
        .CLKOUT(clock_out), // 65.57142857142857 MHz
        .LOCK(locked)
    );

endmodule



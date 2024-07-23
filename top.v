module top(CLK,
           RST_N,
           rs232_SIN,
           rs232_SOUT,
           LED,
           TXP,
           TXN,
           RXP_N,
           RXN_N,
           DBG1,
           DBG2);

    input  CLK;
    input  RST_N;
    input  rs232_SIN;
    output rs232_SOUT;
    output [5 : 0] LED;
    output TXP;
    output TXN;
    input  RXP_N;
    input  RXN_N;
    output DBG1;
    output DBG2;
    wire   CLK_MAIN;
    wire   CLK_UART;

    pll_main pll0(
        .clock_in(CLK),
        .clock_out(CLK_MAIN)
    );

    pll_uart pll1(
        .clock_in(CLK),
        .clock_out(CLK_UART)
    );

    mkTop real_top(
        .CLK_clk_uart(CLK_UART),
        .CLK_clk_slow(CLK),
        .CLK(CLK_MAIN),
        .RST_N(RST_N),
        .rs232_SIN(rs232_SIN),
        .rs232_SOUT(rs232_SOUT),
        .LED(LED),
        .txp(TXP),
        .txn(TXN),
        .rxp_n(RXP_N),
        .rxn_n(RXN_N),
        .dbg1(DBG1),
        .dbg2(DBG2)
    );

endmodule

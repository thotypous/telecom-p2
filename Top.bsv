import RS232::*;
import GetPut::*;
import ThreeLevelIO::*;
import HDB3Encoder::*;
import HDB3Decoder::*;
import E1Unframer::*;
import HDLCUnframer::*;
import ICMPReplier::*;
import HDLCFramer::*;
import Connectable::*;
import BUtils::*;
import PAClib::*;
import FIFOF::*;
import Vector::*;
import Clocks::*;

interface Top;
    interface RS232 rs232;
    interface Reset rs232_rst;
    (* always_ready, prefix="", result="LED" *)
    method Bit#(6) led;
    (* prefix="" *)
    interface ThreeLevelIOPins tlio_pins;
    (* always_ready *)
    method Bool dbg2;
endinterface

(* synthesize *)
module mkTop#(Clock clk_uart, Clock clk_slow)(Top);
    Reset rst_uart <- mkAsyncResetFromCR(2, clk_uart);
    UART#(16) uart <- mkUART(8, NONE, STOP_1, 1, clocked_by clk_uart, reset_by rst_uart);
    rule discard_uart_input;
        let b <- uart.tx.get;
    endrule

    Reg#(Bit#(6)) led_reg <- mkReg(0);

    ThreeLevelIO tlio <- mkThreeLevelIO(True);
    HDB3Encoder hdb3enc <- mkHDB3Encoder;
    mkConnection(hdb3enc.out, tlio.in);

    HDB3Decoder hdb3dec <- mkHDB3Decoder;
    mkConnection(tlio.out, hdb3dec.in);

    E1Unframer unfr <- mkE1Unframer;
    mkConnection(hdb3dec.out, unfr.in);

    HDLCUnframer unhdlc <- mkHDLCUnframer;

    rule select_desired_ts;
        match {.ts, .value} <- unfr.out.get;
        if (ts != 0) action
            unhdlc.in.put(value);
        endaction
    endrule

    Reg#(LBit#(1506)) frame_size <- mkReg(0);
    SyncFIFOIfc#(Bit#(8)) fifo_uart <- mkSyncFIFOFromCC(2, clk_uart);
    mkConnection(toGet(fifo_uart), uart.rx);

    Reset rst_slow <- mkAsyncResetFromCR(2, clk_slow);
    ICMPReplier icmp <- mkICMPReplier(clocked_by clk_slow, reset_by rst_slow);
    SyncFIFOIfc#(Tuple2#(Bool, Bit#(8))) icmp_in <- mkSyncFIFOFromCC(2, clk_slow);
    SyncFIFOIfc#(Tuple2#(Bool, Bit#(8))) icmp_out <- mkSyncFIFOToCC(2, clk_slow, rst_slow);
    mkConnection(toGet(icmp_in), icmp.in);
    mkConnection(icmp.out, toPut(icmp_out));

    rule unhdlc_to_icmp;
        match {.sof, .octet} <- unhdlc.out.get;
        //fifo_uart.enq(octet);  // debugging example: send all received packets to UART
        icmp_in.enq(tuple2(sof, octet));
        frame_size <= sof ? 1 : frame_size + 1;
        if (frame_size == 6)  // cHDLC header + FCS
            led_reg <= led_reg + 1;
    endrule

    HDLCFramer hdlc <- mkHDLCFramer;
    mkConnection(toGet(icmp_out), hdlc.in);

    // E1 framer
    Reg#(Bit#(9)) tx_index <- mkReg(0);
    rule produce_fas_nfas (tx_index[7:0] < 8);
        let i = tx_index[7:0];
        let fas_nfas = reverseBits(tx_index[8] == 1'b0 ? 8'b10011011 : 8'b11000111);
        hdb3enc.in.put(fas_nfas[i]);
        tx_index <= tx_index + 1;
    endrule
    rule produce_hdlc (tx_index[7:0] >= 8);
        let b <- hdlc.out.get;
        hdb3enc.in.put(b);
        tx_index <= tx_index + 1;
    endrule

    interface rs232 = uart.rs232;
    interface rs232_rst = rst_uart;
    method led = ~led_reg;
    interface tlio_pins = tlio.pins;
    method dbg2 = tx_index == 0;
endmodule

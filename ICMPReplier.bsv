import GetPut::*;
import Connectable::*;
import FIFOF::*;
import SpecialFIFOs::*;
import BUtils::*;
import CRC::*;
import Vector::*;

interface ICMPReplier;
    interface Put#(Tuple2#(Bool, Bit#(8))) in;
    interface Get#(Tuple2#(Bool, Bit#(8))) out;
endinterface

typedef enum {
    WAIT_START,
    PROCESS_FRAME,
    PRODUCE_FCS2
} State deriving (Bits, Eq, FShow);

module mkICMPReplier(ICMPReplier);
    FIFOF#(Tuple2#(Bool, Bit#(8))) fifo_out <- mkFIFOF;
    Vector#(8, FIFOF#(Tuple2#(Bool, Bit#(8)))) fifos <- replicateM(mkPipelineFIFOF);
    function fv(i) = tpl_2(fifos[i].first);

    for (Integer i = 0; i < 7; i = i + 1)
        mkConnection(toGet(fifos[i+1]), toPut(fifos[i]));

    Reg#(LBit#(1506)) cur_pos <- mkReg(0);
    Reg#(LBit#(1506)) last_pos <- mkReg(1506);
    let pos_last = cur_pos == last_pos;
    Reg#(Bit#(56)) buffer <- mkRegU;
    Reg#(Bit#(8)) checksum2 <- mkRegU;
    CRC#(16) crc <- mkCRC('h1021, 'hFFFF, 'hFFFF, True, True);
    Reg#(State) state <- mkReg(WAIT_START);

    function produce_out(value) = action
        crc.add(value);
        fifo_out.enq(tuple2(False, value));
    endaction;

    function finish(success) = action
        $display("ICMPReplier: finish: success = ", success);
        let value = crc.result[7:0];
        if (!success)
            // Produce deliberately incorrect FCS. A better implementation
            // would signal HDLCFramer to produce 'h7F (abort) instead.
            value = ~value;
        fifo_out.enq(tuple2(False, value));
        state <= PRODUCE_FCS2;
    endaction;

    function advance_in = action
        cur_pos <= cur_pos + 1;
        fifos[0].deq;
    endaction;

    rule discard_until_start (fifos[0].first matches {.sof, .value} &&& !sof && state == WAIT_START);
        $display("ICMPReplier: discarding %h", value);
        fifos[0].deq;
    endrule

    rule handle_start (fifos[0].first matches {.sof, .value} &&& sof && !pos_last && state != PRODUCE_FCS2);
        let is_unicast = fv(0) == 'h0f;
        let is_ip = {fv(2), fv(3)} == 'h0800;
        let is_v4 = fv(4) == 'h45;
        let datagram_len = {fv(6), fv(7)};
        $display("ICMPReplier: handle start: is_unicast = ", is_unicast, ", is_ip = ", is_ip, ", is_v4 = ", is_v4, ", datagram_len = ", datagram_len);
        if (is_unicast && is_ip && is_v4) action
            cur_pos <= 1;
            last_pos <= truncate(datagram_len + 4);
            produce_out(value);
            state <= PROCESS_FRAME;
        endaction else action
            state <= WAIT_START;
        endaction
        fifos[0].deq;
    endrule

    let pos_proto = cur_pos == 13;
    rule check_if_icmp (fifos[0].first matches {.sof, .value} &&& !sof && state == PROCESS_FRAME && !pos_last && pos_proto);
        $display("ICMPReplier: check if icmp: value = ", value);
        if (value == 'h01)  // ICMP
            produce_out(value);
        else
            finish(False);
        advance_in;
    endrule

    let pos_addr_first = cur_pos == 16;
    rule invert_addr_init (fifos[0].first matches {.sof, .value} &&& !sof && state == PROCESS_FRAME && !pos_last && pos_addr_first);
        $display("ICMPReplier: invert addresses init");
        produce_out(fv(4));
        buffer <= {fv(5), fv(6), fv(7), fv(0), fv(1), fv(2), fv(3)};
        advance_in;
    endrule

    let pos_addr = cur_pos > 16 && cur_pos < 16 + 8;
    rule invert_addr (fifos[0].first matches {.sof, .value} &&& !sof && state == PROCESS_FRAME && !pos_last && pos_addr);
        $display("ICMPReplier: invert addresses, buffer = ", buffer);
        produce_out(truncateLSB(buffer));
        buffer <= buffer << 8;
        advance_in;
    endrule

    let pos_icmp_type = cur_pos == 24;
    rule check_if_echo_request (fifos[0].first matches {.sof, .value} &&& !sof && state == PROCESS_FRAME && !pos_last && pos_icmp_type);
        $display("ICMPReplier: check if echo request: value = ", value);
        if (value == 'h08) // Echo Request
            produce_out('h00); // Echo Reply
        else
            finish(False);
        advance_in;
    endrule

    let pos_checksum1 = cur_pos == 26;
    rule fix_checksum1 (fifos[0].first matches {.sof, .value} &&& !sof && state == PROCESS_FRAME && !pos_last && pos_checksum1);
        let checksum = {fv(0), fv(1)};
        $display("ICMPReplier: original checksum = %h", checksum);
        let ckfix = {4'b0, checksum} + 'h0800;
        checksum = ckfix[15:0] + extend(ckfix[19:16]);
        $display("ICMPReplier: fixed checksum = %h", checksum);
        produce_out(checksum[15:8]);
        checksum2 <= checksum[7:0];
        advance_in;
    endrule
    
    let pos_checksum2 = cur_pos == 27;
    rule fix_checksum2 (fifos[0].first matches {.sof, .value} &&& !sof && state == PROCESS_FRAME && !pos_last && pos_checksum2);
        produce_out(checksum2);
        advance_in;
    endrule
    
    rule process_frame_default (fifos[0].first matches {.sof, .value} &&& !sof && state == PROCESS_FRAME &&
            !pos_last && !pos_proto && !pos_addr_first && !pos_addr && !pos_icmp_type && !pos_checksum1 && !pos_checksum2);
        $display("ICMPReplier: rolling on: value = ", value, ", cur_pos = ", cur_pos, ", last_pos = ", last_pos);
        produce_out(value);
        advance_in;
    endrule

    rule process_frame_end (state == PROCESS_FRAME && pos_last);
        finish(True);
    endrule

    rule produce_fcs2 (state == PRODUCE_FCS2);
        let fcs <- crc.complete;
        fifo_out.enq(tuple2(True, fcs[15:8]));
        cur_pos <= 0;
        last_pos <= 1506;
        state <= WAIT_START;
    endrule

    interface out = toGet(fifo_out);
    interface in = toPut(fifos[7]);
endmodule

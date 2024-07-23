import GetPut::*;
import FIFOF::*;

interface HDLCFramer;
    interface Put#(Tuple2#(Bool, Bit#(8))) in;
    interface Get#(Bit#(1)) out;
endinterface

typedef enum {
    IDLE,
    PROCESS_FRAME,
    FRAME_ADD_ZERO,
    END_OF_FRAME
} State deriving (Eq, Bits, FShow);

module mkHDLCFramer(HDLCFramer);
    FIFOF#(Tuple2#(Bool, Bit#(8))) fifo_in <- mkFIFOF;
    FIFOF#(Bit#(1)) fifo_out <- mkSizedFIFOF(8);

    Bit#(8) hdlc_flag = 8'b01111110;
    
    Reg#(State) state <- mkReg(IDLE);
    Reg#(State) next_state <- mkRegU;
    Reg#(Bit#(3)) index_k <- mkReg(0);
    Reg#(Bit#(4)) recent_bits <- mkReg(0);

    rule produce_flag (state == END_OF_FRAME || state == IDLE);
        let b = hdlc_flag[index_k];
        fifo_out.enq(b);
        recent_bits <= recent_bits << 1 | extend(b);
        if (index_k == 7) action
            state <= fifo_in.notEmpty ? PROCESS_FRAME : IDLE;
        endaction
        index_k <= index_k + 1;
        $display("HDLCFramer: produce_flag: state = ", fshow(state), ", index_k = ", index_k, ", b = ", b);
    endrule

    rule process_frame (state == PROCESS_FRAME);
        match {.eof, .value} = fifo_in.first;
        let b = value[index_k];
        fifo_out.enq(b);
        recent_bits <= recent_bits << 1 | extend(b);
        let eof_lastb = eof && index_k == 7;
        if ({recent_bits, b} == 5'b11111) action
            state <= FRAME_ADD_ZERO;
            next_state <= eof_lastb ? END_OF_FRAME : PROCESS_FRAME;
        endaction else if (eof_lastb) action
            state <= END_OF_FRAME;
        endaction
        if (index_k == 7)
            fifo_in.deq;
        index_k <= index_k + 1;
        $display("HDLCFramer: process_frame: b = ", b, ", index_k = ", index_k);
    endrule

    rule frame_add_zero (state == FRAME_ADD_ZERO);
        fifo_out.enq(0);
        recent_bits <= recent_bits << 1;
        state <= next_state;
        $display("HDLCFramer: frame_add_zero: next_state = ", fshow(next_state));
    endrule
    
    interface in = toPut(fifo_in);

    interface out = toGet(fifo_out);
endmodule

import GetPut::*;
import FIFOF::*;
import Assert::*;

interface HDLCUnframer;
    interface Put#(Bit#(1)) in;
    interface Get#(Tuple2#(Bool, Bit#(8))) out;
endinterface

module mkHDLCUnframer(HDLCUnframer);
    // Sugestão de elementos de estado (podem ser alterados caso conveniente)
    FIFOF#(Tuple2#(Bool, Bit#(8))) fifo_out <- mkFIFOF;
    Reg#(Bool) start_of_frame <- mkReg(True);
    Bit#(9) octet_reset_value = 9'b1_0000_0000;
    Reg#(Bit#(9)) octet <- mkReg(octet_reset_value);
    Reg#(Bit#(7)) recent_bits <- mkReg(0);

    interface out = toGet(fifo_out);

    interface Put in;
        method Action put(Bit#(1) b);
            // TODO: preencha aqui com a sua lógica
        endmethod
    endinterface
endmodule

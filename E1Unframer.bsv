import GetPut::*;
import FIFOF::*;
import Assert::*;

typedef Bit#(TLog#(32)) Timeslot;

interface E1Unframer;
    interface Put#(Bit#(1)) in;
    interface Get#(Tuple2#(Timeslot, Bit#(1))) out;
endinterface

typedef enum {
    UNSYNCED,
    FIRST_FAS,
    FIRST_NFAS,
    SYNCED
} State deriving (Bits, Eq, FShow);

module mkE1Unframer(E1Unframer);
    // Sugestão de elementos de estado (podem ser alterados caso conveniente)
    FIFOF#(Tuple2#(Timeslot, Bit#(1))) fifo_out <- mkFIFOF;
    Reg#(State) state <- mkReg(UNSYNCED);
    Reg#(Bit#(TLog#(8))) cur_bit <- mkRegU;
    Reg#(Timeslot) cur_ts <- mkRegU;
    Reg#(Bool) fas_turn <- mkRegU;
    Reg#(Bit#(8)) cur_byte <- mkReg(0);

    interface out = toGet(fifo_out);

    interface Put in;
        method Action put(Bit#(1) b);
            // TODO: preencha aqui com a sua lógica
        endmethod
    endinterface
endmodule

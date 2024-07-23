import GetPut::*;
import Connectable::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import Assert::*;
import ThreeLevelIO::*;

interface HDB3Encoder;
    interface Put#(Bit#(1)) in;
    interface Get#(Symbol) out;
endinterface

typedef enum {
    IDLE_OR_S1,
    S2,
    S3,
    S4
} State deriving (Bits, Eq, FShow);

module mkHDB3Encoder(HDB3Encoder);
    Vector#(4, FIFOF#(Bit#(1))) fifos <- replicateM(mkPipelineFIFOF);

    Reg#(Bool) last_pulse_p <- mkReg(False);
    Reg#(Bool) last_violation_p <- mkReg(True);
    Reg#(State) state <- mkReg(IDLE_OR_S1);

    for (Integer i = 0; i < 3; i = i + 1)
        mkConnection(toGet(fifos[i+1]), toPut(fifos[i]));

    interface in = toPut(fifos[3]);

    interface Get out;
        method ActionValue#(Symbol) get;
            let recent_bits = tuple4(fifos[0].first, fifos[1].first, fifos[2].first, fifos[3].first);
            let value = Z;

            case (state)
                IDLE_OR_S1:
                    if (tpl_1(recent_bits) == 1) action
                        // AMI-like encoding
                        value = last_pulse_p ? N : P;
                        last_pulse_p <= !last_pulse_p;
                    endaction else
                    if (recent_bits == tuple4(0, 0, 0, 0)) action
                        if (last_pulse_p == last_violation_p) action
                            value = last_pulse_p ? N : P;   // implement rule 2 (B pulse)
                            last_pulse_p <= !last_pulse_p;
                        endaction
                        state <= S2;
                    endaction
                S2:
                    action
                        dynamicAssert(tpl_1(recent_bits) == 0, "unexpected value on S2");
                        state <= S3;
                    endaction
                S3:
                    action
                        dynamicAssert(tpl_1(recent_bits) == 0, "unexpected value on S3");
                        state <= S4;
                    endaction
                S4:
                    action
                        dynamicAssert(tpl_1(recent_bits) == 0, "unexpected value on S4");
                        value = last_pulse_p ? P : N;   // implement rule 1 (V pulse)
                        last_violation_p <= last_pulse_p;
                        state <= IDLE_OR_S1;
                    endaction
            endcase

            $display("HDB3Encoder: recent_bits = ", fshow(recent_bits),
                ", value = ", fshow(value),
                ", last_pulse_p = ", last_pulse_p,
                ", last_violation_p = ", last_violation_p,
                ", state = ", fshow(state));

            fifos[0].deq;
            return value;
        endmethod
    endinterface
endmodule

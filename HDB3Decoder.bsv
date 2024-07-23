import GetPut::*;
import Connectable::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Vector::*;
import Assert::*;
import ThreeLevelIO::*;

interface HDB3Decoder;
    interface Put#(Symbol) in;
    interface Get#(Bit#(1)) out;
endinterface

typedef enum {
    IDLE_OR_S1,
    S2,
    S3,
    S4
} State deriving (Bits, Eq, FShow);

module mkHDB3Decoder(HDB3Decoder);
    // Sugestão de elementos de estado (podem ser alterados caso conveniente)
    Vector#(4, FIFOF#(Symbol)) fifos <- replicateM(mkPipelineFIFOF);
    Reg#(Bool) last_pulse_p <- mkReg(False);
    Reg#(State) state <- mkReg(IDLE_OR_S1);

    for (Integer i = 0; i < 3; i = i + 1)
        mkConnection(toGet(fifos[i+1]), toPut(fifos[i]));

    interface in = toPut(fifos[3]);

    interface Get out;
        method ActionValue#(Bit#(1)) get;
            let recent_symbols = tuple4(fifos[0].first, fifos[1].first, fifos[2].first, fifos[3].first);
            let value = 0;

            // TODO: preencha aqui com a sua lógica

            fifos[0].deq;
            return value;
        endmethod
    endinterface
endmodule

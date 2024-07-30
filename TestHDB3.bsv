import BUtils::*;
import GetPut::*;
import Connectable::*;
import Assert::*;
import FIFOF::*;
import Randomizable::*;
import StmtFSM::*;
import HDB3Encoder::*;
import HDB3Decoder::*;

(* synthesize *)
module mkTestHDB3(Empty);
    let hdb3enc <- mkHDB3Encoder;
    let hdb3dec <- mkHDB3Decoder;
    mkConnection(hdb3enc.out, hdb3dec.in);

    Randomize#(Bit#(1)) contents_rng <- mkGenericRandomizer;

    Reg#(Bool) rng_initialized <- mkReg(False);
    rule rng_init (!rng_initialized);
        contents_rng.cntrl.init;
        rng_initialized <= True;
    endrule

    Reg#(Bit#(16)) i <- mkReg(0);
    FIFOF#(Bit#(1)) expected_out <- mkSizedFIFOF(7);

    mkAutoFSM(seq
        while (i != maxBound) action
            let b <- contents_rng.next;

            hdb3enc.in.put(b);
            expected_out.enq(b);

            i <= i + 1;
        endaction

        delay(4);
        $display("SUCCESS");
    endseq);

    rule check_out;
        let obtained <- hdb3dec.out.get;
        let expected <- toGet(expected_out).get;
        $display("TestHDB3: obtained ", fshow(obtained),
            ", expected ", fshow(expected));
        dynamicAssert(obtained == expected, "wrong output obtained from HDB3Decoder");
    endrule
endmodule

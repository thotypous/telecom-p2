import BUtils::*;
import GetPut::*;
import Connectable::*;
import Assert::*;
import FIFOF::*;
import Randomizable::*;
import StmtFSM::*;
import HDLCFramer::*;
import HDLCUnframer::*;

typedef LBit#(1500) FrameSize;

(* synthesize *)
module mkTestHDLC(Empty);
    let hdlc <- mkHDLCFramer;
    let unhdlc <- mkHDLCUnframer;
    mkConnection(hdlc.out, unhdlc.in);

    Randomize#(Bit#(8)) contents_rng <- mkGenericRandomizer;
    Randomize#(FrameSize) size_rng <- mkConstrainedRandomizer(1, 1500);

    Reg#(Bool) rng_initialized <- mkReg(False);
    rule rng_init (!rng_initialized);
        contents_rng.cntrl.init;
        size_rng.cntrl.init;
        rng_initialized <= True;
    endrule

    Reg#(Bit#(7)) i <- mkReg(0);
    Reg#(FrameSize) remaining_bytes <- mkRegU;
    Reg#(Bool) start_of_frame <- mkRegU;
    FIFOF#(Tuple2#(Bool, Bit#(8))) expected_out <- mkFIFOF;

    mkAutoFSM(seq
        while (i != maxBound) seq
            action
                let size <- size_rng.next;
                remaining_bytes <= size;
                start_of_frame <= True;
                
                i <= i + 1;
            endaction

            while (remaining_bytes != 0) action
                let end_of_frame = remaining_bytes == 1;
                let octet <- contents_rng.next;

                hdlc.in.put(tuple2(end_of_frame, octet));
                expected_out.enq(tuple2(start_of_frame, octet));

                start_of_frame <= False;
                remaining_bytes <= remaining_bytes - 1;
            endaction
        endseq

        delay(10);
        $display("SUCCESS");
    endseq);

    rule check_out;
        let obtained <- unhdlc.out.get;
        let expected <- toGet(expected_out).get;
        $display("TestHDLC: obtained ", fshow(obtained),
            ", expected ", fshow(expected));
        dynamicAssert(obtained == expected, "wrong output obtained from HDLCUnframer");
    endrule
endmodule

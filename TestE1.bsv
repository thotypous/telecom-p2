import BUtils::*;
import GetPut::*;
import Connectable::*;
import Assert::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Randomizable::*;
import StmtFSM::*;
import PAClib::*;
import SingleElemVector::*;
import E1Unframer::*;

(* synthesize *)
module mkTestE1(Empty);
    let unfr <- mkE1Unframer;

    FIFOF#(Bit#(8)) ser_fifo <- mkBypassFIFOF;
    PipeOut#(Bit#(1)) ser_pipe <- mkCompose(
        mkCompose(
            mkFn_to_Pipe(reverseBits),
            mkFn_to_Pipe(unpack)),
        mkCompose(
            mkFunnel,
            mkFn_to_Pipe(vecUnbind)),
        f_FIFOF_to_PipeOut(ser_fifo));

    FIFOF#(Bit#(1)) direct_in <- mkBypassFIFOF;
    
    rule direct_in_to_unfr;
        let b <- toGet(direct_in).get;
        unfr.in.put(b);
    endrule

    rule ser_pipe_to_unfr (!direct_in.notEmpty);
        let b <- toGet(ser_pipe).get;
        unfr.in.put(b);
    endrule
    
    Randomize#(Bit#(8)) rng <- mkGenericRandomizer;

    Reg#(Bool) rng_initialized <- mkReg(False);
    rule rng_init (!rng_initialized);
        rng.cntrl.init;
        rng_initialized <= True;
    endrule
    
    FIFOF#(Tuple2#(Timeslot, Bit#(1))) expected_out <- mkFIFOF;
    FIFOF#(Tuple2#(Timeslot, Bit#(1))) obtained_out <- mkFIFOF;
    mkConnection(unfr.out, toPut(obtained_out));
    
    Reg#(Bit#(5)) i <- mkReg(0);
    Reg#(Bit#(9)) zfilling <- mkRegU;
    Reg#(Bit#(5)) num_frames <- mkRegU;
    Reg#(Bit#(5)) j <- mkRegU;
    Reg#(LBit#(TMul#(31, 8))) k <- mkRegU;

    mkAutoFSM(seq
        while (i != maxBound) seq
            action
                let rnd <- rng.next;
                zfilling <= extend(rnd) + 8;
                i <= i + 1;
            endaction

            while (zfilling != 0) action
                $display("TestE1: forcing out of sync by feeding zero filling");
                direct_in.enq(0);
                zfilling <= zfilling - 1;
            endaction

            action
                let rnd <- rng.next;
                num_frames <= truncate(rnd);
                j <= 0;
            endaction

            while (j != num_frames) seq
                action
                    let octet <- rng.next;
                    if (j[0] == 1'b0) action
                        $display("TestE1: feeding FAS");
                        octet[6:0] = 7'b0011011;
                    endaction else action
                        $display("TestE1: feeding NFAS");
                        octet[6] = 1'b1;
                    endaction
                    ser_fifo.enq(octet);
                    k <= 0;
                    j <= j + 1;
                endaction

                await(!ser_pipe.notEmpty);

                while (k < 31*8) action
                    let rnd <- rng.next;
                    Timeslot ts = truncate(1 + k / 8);
                    if (j > 2) action
                        $display("TestE1: feeding data for TS", ts, ": ", rnd[0], " (should be sync)");
                        // o E1Unframer só deve produzir saída quando sincronizado
                        expected_out.enq(tuple2(ts, rnd[0]));
                    endaction else action
                        $display("TestE1: feeding data for TS", ts, ": ", rnd[0], " (should be out of sync)");
                    endaction
                    direct_in.enq(rnd[0]);
                    k <= k + 1;
                endaction
            endseq
        endseq

        delay(32);
        $display("SUCCESS");
    endseq);

    rule check_output (obtained_out.first matches {.ts, .b} &&& ts != 0);
        let obtained <- toGet(obtained_out).get;
        let expected <- toGet(expected_out).get;
        $display("TestE1: obtained ", fshow(obtained),
            ", expected ", fshow(expected));
        dynamicAssert(obtained == expected, "wrong output obtained from E1Unframer");
    endrule
    
    rule ignore_ts0 (obtained_out.first matches {.ts, .b} &&& ts == 0);
        obtained_out.deq;
        $display("TestE1: skipping check on TS0 contents: ", fshow(b));
    endrule

endmodule

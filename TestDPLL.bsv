import BUtils::*;
import GetPut::*;
import Vector::*;
import Assert::*;
import FIFOF::*;
import Randomizable::*;
import ThreeLevelIO::*;

typedef Bit#(16) Index;

(* synthesize *)
module mkTestDPLL(Empty);
    ThreeLevelIO tlio <- mkThreeLevelIO(True);

    LBit#(CyclesPerSymbol) counter_max_value = fromInteger(valueOf(CyclesPerSymbol) - 1);
    Reg#(LBit#(CyclesPerSymbol)) counter_reset_value <- mkReg(counter_max_value);
    Reg#(LBit#(CyclesPerSymbol)) counter <- mkReg(0);

    Randomize#(LBit#(CyclesPerSymbol)) deviation_rng <- mkConstrainedRandomizer(0, 1);

    Reg#(Index) index <- mkReg(0);
    FIFOF#(Index) index_fifo <- mkSizedFIFOF(4);
    Index lock_tolerance = 32;  // até qual índice é tolerado que a DPLL ainda não esteja travada 

    Vector#(3, Tuple2#(Bit#(1), Bit#(1))) produce_rx_seq = cons(tuple2(0,1), cons(tuple2(1,1), cons(tuple2(1,0), nil)));

    Reg#(Bool) rng_initialized <- mkReg(False);
    rule rng_init (!rng_initialized);
        deviation_rng.cntrl.init;
        rng_initialized <= True;
    endrule

    rule produce_rx;
        let cur_rx = produce_rx_seq[index % 3];
        if (counter == 0) begin
            index_fifo.enq(index);
            let deviation <- deviation_rng.next;
            let next_reset_value = counter_max_value;
            if (index < maxBound >> 1) begin
                // primeira metade do teste com período de clock superior ao nosso
                next_reset_value = next_reset_value + deviation;
            end else begin
                // segunda metade do teste com período de clock inferior ao nosso
                next_reset_value = next_reset_value - deviation;
            end
            $display("TestDPLL: producing ", fshow(cur_rx),
                " for ", {1'b0, next_reset_value} + 1,
                " samples");
            counter_reset_value <= next_reset_value;
        end
        if (counter == counter_reset_value) begin
            counter <= 0;
            index <= index + 1;
        end else begin
            counter <= counter + 1;
        end
        if (counter >= counter_max_value >> 1) begin
            cur_rx = tuple2(1, 1);  // Return-to-zero
        end
        tlio.pins.recv(tpl_1(cur_rx), tpl_2(cur_rx));
    endrule

    Vector#(3, Symbol) check_rx_seq = cons(P, cons(Z, cons(N, nil)));

    rule check_rx;
        let index <- toGet(index_fifo).get;
        let symbol <- tlio.out.get;
        let expected = check_rx_seq[index % 3];
        $display("TestDPLL: ", index,
            ": sampled ", fshow(symbol),
            ", expected ", fshow(expected));
        dynamicAssert(symbol == expected || index <= lock_tolerance,
            "sampled unexpected symbol");
        if (index == maxBound) begin
            $display("SUCCESS");
            $finish;
        end
    endrule

endmodule

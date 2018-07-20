import GetPut::*;
import Vector::*;
import FIFO::*;
import Clocks::*;


function ActionValue#(tdata) get(tifc ifc) provisos(ToGet#(tifc, tdata))
  = toGet(ifc).get;


interface FIFO_N_to_1#(numeric type n, type d);
  interface Put#(Vector#(n, d)) put;
  interface Get#(d) get;
endinterface

module mkFIFO_N_to_1#(Integer depth) (FIFO_N_to_1#(n, d)) provisos (Bits#(d, dsz));
  Vector#(n, FIFO#(d)) f <- replicateM(mkSizedFIFO(depth));
  Reg#(Bit#(TLog#(n))) id <- mkReg(0);
  
  interface Put put;
    method Action put (Vector#(n, d) v);
      for (Integer i = 0; i < valueOf(n); i = i + 1) 
        f[i].enq(v[i]);
    endmethod
  endinterface
  
  interface Get get;
    method ActionValue#(d) get;
      let d <- get(f[id]);
      id <= (id == fromInteger(valueOf(TSub#(n, 1)))) ? 0 : id + 1;
      return d;
    endmethod
  endinterface
endmodule


// This FIFO can be used to, for example, in a scenario where a chip's core clock and io clock are different, and the io is serialized. So here to send data out of the chip, get is on get_clk (io clock) and put is on the default clock (which is the core clock in this case).

module mkSyncFIFO_N_to_1#(Integer depth, Clock get_clk, Reset get_rst_n) (FIFO_N_to_1#(n, d) ifc) provisos (Bits#(d, dsz));
  Vector#(n, SyncFIFOIfc#(d)) f <- replicateM(mkSyncFIFOFromCC(depth, get_clk));
  Reg#(Bit#(TLog#(n))) id <- mkReg(0, clocked_by get_clk, reset_by get_rst_n);
  
  interface Put put;
    method Action put (Vector#(n, d) v);
      for (Integer i = 0; i < valueOf(n); i = i + 1) 
        f[i].enq(v[i]);
    endmethod
  endinterface
  
  interface Get get;
    method ActionValue#(d) get;
      let d <- get(f[id]);
      id <= (id == fromInteger(valueOf(TSub#(n, 1)))) ? 0 : id + 1;
      return d;
    endmethod
  endinterface
endmodule


// Example instantiation

// Single clock
typedef Bit#(8) Byte;

(* synthesize *)

module mkFIFO_8_to_1_Byte(FIFO_N_to_1#(8, Byte));
  Integer depth = 2;
  let dut <- mkFIFO_N_to_1(depth);
  return dut;
endmodule

// Two clocks

(* synthesize *)

module mkSyncFIFO_8_to_1_Byte#(Clock io_clk, Reset io_rst_n)(FIFO_N_to_1#(8, Byte));
  Integer depth = 2;
  let dut <- mkSyncFIFO_N_to_1(depth, io_clk, io_rst_n);
  return dut;
endmodule

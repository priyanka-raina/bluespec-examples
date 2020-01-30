import FIFO::*;
import GetPut::*;
import CGetPut::*;
import Connectable::*;

typedef enum {CONFIGURE, PROCESS} State deriving (Bits, Eq);

interface Chip2ChipFIFOs#(numeric type width, numeric type depth);
  interface CPut#(depth, Bit#(width)) put_data;
  interface CGet#(depth, Bit#(width)) get_data;
  method Action set_loopback(Bool loopback);
endinterface

module mkChip2ChipFIFOs (Chip2ChipFIFOs#(width, depth) ifc) 
  provisos(Add#(1, a__, depth));
  
  Tuple2#(Get#(Bit#(width)), CPut#(depth, Bit#(width))) receive_f <- mkGetCPut;
  Tuple2#(CGet#(depth, Bit#(width)), Put#(Bit#(width))) send_f <- mkCGetPut;
  
  let data_to_send <- mkReg(0);
  let data_expected <- mkReg(0);
  Reg#(Bool) loopback_r <- mkReg(False);
  let loopback_f <- mkSizedFIFO(10);
  Reg#(State) state_r <- mkReg(CONFIGURE);

  rule send_data_sequence (state_r == PROCESS);
    if (!loopback_r) begin
      tpl_2(send_f).put(data_to_send);
      $display("Time = %t: %m sent     = %d", $time, data_to_send);
      data_to_send <= data_to_send + 1;
    end else begin
      tpl_2(send_f).put(loopback_f.first);
      loopback_f.deq;
      $display("Time = %t: %m loopback = %d", $time, loopback_f.first);
    end


  endrule

  rule display_received_data (state_r == PROCESS);
    let data_received <- tpl_1(receive_f).get;
    if (loopback_r) begin
      loopback_f.enq(data_received);
    end else begin
      if(data_received != data_expected) $display("Time = %t: Error! %m received = %d, expected = %d", $time, data_received, data_expected);
      data_expected <= data_expected + 1;
    end
    $display("Time = %t: %m received = %d", $time, data_received); 
    if(data_received == 10) $finish;
  endrule
  
  interface put_data = tpl_2(receive_f);
  interface get_data = tpl_1(send_f);

  method Action set_loopback(Bool loopback);
    loopback_r <= loopback;
    state_r <= PROCESS;
  endmethod

endmodule

typedef 16 Width;
typedef 5 Depth;
(* synthesize *)
module mkChip2ChipFIFOsInst (Chip2ChipFIFOs#(Width, Depth));
  let f <- mkChip2ChipFIFOs();
  return f;
endmodule

module mkTbChip2ChipFIFOs (Empty);
  
  let chip0 <- mkChip2ChipFIFOsInst;
  let chip1 <- mkChip2ChipFIFOsInst;

  Reg#(State) state_r <- mkReg(CONFIGURE);

  rule set_loopback (state_r == CONFIGURE);
    chip0.set_loopback(False);
    chip1.set_loopback(True);
    state_r <= PROCESS;
  endrule

  mkConnection(chip0.get_data, chip1.put_data);
  mkConnection(chip1.get_data, chip0.put_data);

endmodule

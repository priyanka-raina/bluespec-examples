import Vector::*;

interface ConnectionBox#(type d, numeric type n);
  (* always_ready *)
  method d mux (Vector#(n, d) in);
  (* always_ready *)
  method Action write_select (Bit#(TLog#(n)) select);
  (* always_ready *)
  method Bit#(TLog#(n)) read_select;
endinterface 

module mkConnectionBox(ConnectionBox#(d, n) ifc); 

  Reg#(Bit#(TLog#(n))) select_r <- mkReg(0);

  method d mux (Vector#(n, d) in) = in[select_r];
  method Action write_select (select) = (action select_r <= select; endaction);
  method read_select = select_r;

endmodule

(* synthesize *)
module mkConnectionBox_16_10(ConnectionBox#(Bit#(16), 10));
  let dut <- mkConnectionBox;
  return dut;
endmodule

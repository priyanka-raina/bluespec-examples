import Vector::*;

interface ConnectionBox#(type d, numeric type n);
  (* always_ready *)
  method d mux (Vector#(n, d) in);
  
  `ifdef HAS_CONSTANT
  (* always_ready *)
  method Action write_select (Bit#(TLog#(TAdd#(n, 1))) select);
  (* always_ready *)
  method Bit#(TLog#(TAdd#(n, 1))) read_select;

  (* always_ready *)
  method Action write_constant (d constant);
  (* always_ready *)
  method d read_constant;
  `else
  (* always_ready *)
  method Action write_select (Bit#(TLog#(n)) select);
  (*always_ready *)
  method Bit#(TLog#(n)) read_select;
  `endif
endinterface 

`ifdef HAS_CONSTANT
module mkConnectionBox#(d default_constant) (ConnectionBox#(d, n)) provisos (NumAlias#(select_bits, TLog#(TAdd#(n, 1))), Bits#(d, a__));
`else
module mkConnectionBox(ConnectionBox#(d, n)) provisos (NumAlias#(select_bits, TLog#(n)));
`endif

  Reg#(Bit#(select_bits)) select_r <- mkReg(0);

  `ifdef HAS_CONSTANT
  Reg#(d) constant_r <- mkReg(default_constant);
  `endif 

  method d mux (Vector#(n, d) in);
    let in_extended = in;
    `ifdef HAS_CONSTANT
    in_extended = cons(constant_r, in);
    `endif
    return in_extended[select_r];
  endmethod

  method Action write_select (select) = (action select_r <= select; endaction);
  method read_select = select_r;
  
  `ifdef HAS_CONSTANT
  method Action write_constant (constant) = (action constant_r <= constant; endaction);
  method read_constant = constant_r;
  `endif
endmodule

(* synthesize *)
module mkConnectionBox_16_10(ConnectionBox#(Bit#(16), 10));
  `ifdef HAS_CONSTANT
  let dut <- mkConnectionBox(23);
  `else
  let dut <- mkConnectionBox();
  `endif
  return dut;
endmodule

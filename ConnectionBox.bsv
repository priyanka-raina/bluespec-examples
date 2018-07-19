// Magma connection box has the following parameters
// width - this is type d in Bluespec
// num_tracks - this is numeric type n
// feedthrough_outputs - this is something that the connection box should not know it should just be given the inputs it is supposed to multiplex, knowledge of feedthrough should be in a higher level module
// has_constant
// default_value 



import Standard::*;


// Connection box without the optional constant feature
interface ConnectionBox#(type d, numeric type n);
  method d mux (Vector#(n, d) in);
  method Action write_select (Bit#(TLog#(n)) select);
  method Bit#(TLog#(n)) read_select;
endinterface 


module mkConnectionBox(ConnectionBox#(d, n) ifc) 
  provisos (NumAlias#(select_bits, TLog#(n)));

  Reg#(Bit#(select_bits)) select_r <- mkReg(0);

  method d mux (Vector#(n, d) in) = in[select_r];
  method Action write_select (select) = (action select_r <= select; endaction);
  method read_select = select_r;

endmodule


(* synthesize *)
module mkConnectionBox_16_10(ConnectionBox#(Bit#(16), 10));
  let dut <- mkConnectionBox;
  return dut;
endmodule


// Connection box with optional constant feature
interface ConnectionBoxWithConstant#(type d, numeric type n, numeric type has_constant);
  method d mux (Vector#(n, d) in);
  method Action write_select (Bit#(TLog#(TAdd#(n, has_constant))) select);
  method Bit#(TLog#(TAdd#(n, has_constant))) read_select;
endinterface 


module mkConnectionBoxWithConstant#(d default_constant) (ConnectionBoxWithConstant#(d, n, has_constant)) 
  provisos (
    NumAlias#(select_bits, TLog#(TAdd#(n, has_constant))),
    Bits#(d, a__),
    Max#(has_constant, 1, 1)
  );

  Reg#(Bit#(select_bits)) select_r <- mkReg(0);

  Reg#(d) constant_r <- mkReg(default_constant);

  method d mux (Vector#(n, d) in);
    let in_and_constant = cons (constant_r, in);
    return in_and_constant[select_r];
  endmethod

  method Action write_select (select) = (action select_r <= select; endaction);
  
  method read_select = select_r;
 
endmodule


(* synthesize *)
module mkConnectionBoxWithConstant_16_10_0(ConnectionBoxWithConstant#(Bit#(16), 10, 0));
  let dut <- mkConnectionBoxWithConstant(23);
  return dut;
endmodule

(* synthesize *)
module mkConnectionBoxWithConstant_16_10_1(ConnectionBoxWithConstant#(Bit#(16), 10, 1));
  let dut <- mkConnectionBoxWithConstant(23);
  return dut;
endmodule

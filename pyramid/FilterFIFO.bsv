import Vector::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

import VectorOps::*;

interface FilterFIFO#(type d, numeric type n);

  method Action enq(d value);
  method Action deq;
  method Action clear;
  method Vector#(n, d) first;
endinterface

module mkFilterFIFO (FilterFIFO#(d, n)) provisos (Bits#(d, dsz), Add#(2, a__, n));
  Vector#(TSub#(n, 1), FIFO#(d)) values <- replicateM(mkLFIFO);
  FIFO#(d) current_value <- mkBypassFIFO;
  PulseWire clear_called <- mkPulseWire();

  /*
  Integer j;
  for (j = 1; j < valueOf(n) - 1; j = j + 1) begin
    rule shiftValue;
      values[j - 1].enq(values[j].first);
      values[j].deq;
    endrule
  end
  */

  Vector#(TSub#(n, 1), Rules) shift_rules;
  for (Integer i = 1; i < valueOf(TSub#(n, 1)); i = i + 1) begin
    shift_rules[i] = (rules
      rule shiftValue;
        values[i - 1].enq(values[i].first);
        values[i].deq;
      endrule
    endrules);
  end
  
  shift_rules[0] = (rules
  rule shiftValueLast;
    values[valueOf(n) - 2].enq(current_value.first);
    current_value.deq;
  endrule
  endrules);

  Rules clear_rules = (rules
    rule clear_fifos (clear_called);
      for (Integer i = 0; i < valueOf(TSub#(n, 1)); i = i + 1)  values[i].clear;
      current_value.clear;
    endrule
  endrules);

  addRules(rJoinMutuallyExclusive(clear_rules, foldl1(rJoin, shift_rules))); 
  
  method Action clear = clear_called.send();
  method Action enq(d value) = current_value.enq(value);
  method Action deq = values[0].deq;
  method Vector#(n, d) first;
    Vector#(n, d) all_values;
    for (Integer i = 0; i < valueOf(TSub#(n, 1)); i = i + 1) all_values[i] = values[i].first;
    all_values[valueOf(n) - 1] = current_value.first;
    return all_values;
  endmethod
endmodule

interface FilterFIFO5#(type d, numeric type hbits, numeric type wbits);
  interface Put#(d) put_one;
  interface Get#(Vector#(5, d)) get_five;
  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
endinterface

module mkFilterFIFO5 (FilterFIFO5#(d, hbits, wbits)) provisos (Bits#(d, dsz));
  FilterFIFO#(d, 5) dut <- mkFilterFIFO;

  Reg#(Bit#(hbits)) w_row_cnt <- mkReg(0);
  Reg#(Bit#(wbits)) w_col_cnt <- mkReg(0);
  Reg#(Bit#(hbits)) r_row_cnt <- mkReg(0);
  Reg#(Bit#(wbits)) r_col_cnt <- mkReg(0);
  
  Reg#(Bit#(hbits)) rows <- mkReg(0);
  Reg#(Bit#(wbits)) cols <- mkReg(0);

  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
    rows <= height;
    cols <= width;
  endmethod

  interface Put put_one;
    method Action put (d v);
      $display("%t wr: (%d, %d) %h", $time, w_row_cnt, w_col_cnt, v);
      dut.enq(v);
      w_row_cnt <= (w_row_cnt == rows - 1) ? 0 : w_row_cnt + 1;
      w_col_cnt <= (w_row_cnt == rows - 1) ? ((w_col_cnt == cols - 1) ? 0 : w_col_cnt + 1) : w_col_cnt;
    endmethod
  endinterface

  interface Get get_five;
    method ActionValue#(Vector#(5, d)) get; 
      let v = dut.first;
      let vv = v;
      case (r_col_cnt)
        0:  case (r_row_cnt)
              0: vv = vector(v[2], v[1], v[0], v[1], v[2]);
              1: vv = vector(v[1], v[0], v[1], v[2], v[3]);
            endcase
        default: case (r_row_cnt)
              0: vv = vector(v[4], v[3], v[2], v[3], v[4]);   
              1: vv = vector(v[2], v[1], v[2], v[3], v[4]);
            endcase
      endcase
      
      case (r_col_cnt)
        (cols - 1): case (r_row_cnt)
          (rows - 2): vv = vector(v[1], v[2], v[3], v[4], v[3]);
          (rows - 1): vv = vector(v[2], v[3], v[4], v[3], v[2]);
        endcase
        default: case (r_row_cnt)
          (rows - 2): vv = vector(v[0], v[1], v[2], v[3], v[2]);
          (rows - 1): vv = vector(v[0], v[1], v[2], v[1], v[0]);
        endcase
      endcase
      
      if (!(
        ((r_col_cnt == 0) && ((r_row_cnt == 0) || (r_row_cnt == 1))) ||
        ((r_col_cnt == cols - 1) && ((r_row_cnt == rows - 3) || (r_row_cnt == rows - 2)))
      )) dut.deq;

      $display("%t rd: (%d, %d) [%h %h  %h  %h %h]", $time, r_row_cnt, r_col_cnt, vv[4], vv[3], vv[2], vv[1], vv[0]);
      r_row_cnt <= (r_row_cnt == rows - 1) ? 0 : r_row_cnt + 1;
      r_col_cnt <= (r_row_cnt == rows - 1) ? ((r_col_cnt == cols - 1) ? 0 : r_col_cnt + 1) : r_col_cnt;
      return vv;
    endmethod
  endinterface
endmodule

(* synthesize *)
module mkTestFilterFIFO5 (FilterFIFO5#(Bit#(16), 11, 11));
  FilterFIFO5#(Bit#(16), 11, 11) dut <- mkFilterFIFO5;
  return dut;
endmodule

typedef enum {CONFIGURE, PROCESS} State deriving (Bits, Eq);

module mkTbFilterFIFO (Empty);
  let dut <- mkTestFilterFIFO5;

  let wcnt <- mkReg(0);
  let rcnt <- mkReg(0);
  let rows <- mkReg(9);
  let cols <- mkReg(5);
  let state <- mkReg(CONFIGURE);
  
  let pixels = rows * cols;

  rule configure (state == CONFIGURE);
    dut.set_image_size(rows, cols);
    state <= PROCESS;
  endrule
  
  rule write ((wcnt < pixels) && (state == PROCESS));
    $display("%t wr: (%d) %h", $time, wcnt, wcnt);
    dut.put_one.put(extend(wcnt));
    wcnt <= wcnt + 1;
  endrule

  rule read ((rcnt < pixels) && (state == PROCESS));
    let d <- dut.get_five.get;
    $display("%t rd: (%d) [%h %h  %h  %h %h]", $time, rcnt, d[4], d[3], d[2], d[1], d[0]);
    rcnt <= rcnt + 1;
  endrule

  rule stop ((rcnt >= pixels) && (state == PROCESS));
    $finish;
  endrule
endmodule

//------------------------------------------------------------------------------
// n = 1
//------------------------------------------------------------------------------

// FIFO for 2n + 1 length filter
interface SizedFilterFIFO1#(type d, numeric type hbits, numeric type wbits);
  interface Put#(d) put;
  interface Get#(Vector#(3, d)) get;
  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
endinterface

module mkSizedFilterFIFO1 (SizedFilterFIFO1#(d, hbits, wbits)) 
  provisos (
    Bits#(d, dsz),
    Add#(a__, TLog#(3), hbits),
    FShow#(Vector::Vector#(3, d)),
    Add#(1, b__, 2)
  );
  FilterFIFO#(d, 3) dut <- mkFilterFIFO;

  Reg#(Bit#(hbits)) w_row_cnt <- mkReg(0);
  Reg#(Bit#(wbits)) w_col_cnt <- mkReg(0);
  Reg#(Bit#(hbits)) r_row_cnt <- mkReg(0);
  Reg#(Bit#(wbits)) r_col_cnt <- mkReg(0);
  
  Reg#(Bit#(hbits)) rows <- mkReg(0);
  Reg#(Bit#(wbits)) cols <- mkReg(0);

  function Vector#(3, d) permute (Vector#(3, d) v);
      let vv = v;
      case (r_col_cnt)
        0:  case (r_row_cnt)
              0: vv = vector(v[1], v[0], v[1]);
            endcase
        default: case (r_row_cnt)
              0: vv = vector(v[2], v[1], v[2]);   
            endcase
      endcase
      
      case (r_col_cnt)
        (cols - 1): case (r_row_cnt)
          (rows - 1): vv = vector(v[1], v[2], v[1]);
        endcase
        default: case (r_row_cnt)
          (rows - 1): vv = vector(v[0], v[1], v[0]);
        endcase
      endcase
      return vv;
  endfunction

  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
    rows <= height;
    cols <= width;
  endmethod

  interface Put put;
    method Action put (d v);
      dut.enq(v);
      w_row_cnt <= (w_row_cnt == rows - 1) ? 0 : w_row_cnt + 1;
      w_col_cnt <= (w_row_cnt == rows - 1) ? ((w_col_cnt == cols - 1) ? 0 : w_col_cnt + 1) : w_col_cnt;
    endmethod
  endinterface

  interface Get get;
    method ActionValue#(Vector#(3, d)) get; 
      let v = dut.first;
        
      let vv = permute(v); 
      
      if (!(
        ((r_col_cnt == 0) && (r_row_cnt < 1)) ||
        ((r_col_cnt == cols - 1) && ((r_row_cnt >= rows - 1 - 1) && (r_row_cnt <= rows - 1)))
      )) begin 
        dut.deq;
      end else if ((r_col_cnt == cols - 1) && (r_row_cnt == rows - 1))
        dut.clear;


      r_row_cnt <= (r_row_cnt == rows - 1) ? 0 : r_row_cnt + 1;
      r_col_cnt <= (r_row_cnt == rows - 1) ? ((r_col_cnt == cols - 1) ? 0 : r_col_cnt + 1) : r_col_cnt;
      return vv;
    endmethod
  endinterface
endmodule



//------------------------------------------------------------------------------
/*
module mkSizedFilterFIFO2 (SizedFilterFIFO#(d, 2, hbits, wbits)) 
  provisos (
    Bits#(d, dsz),
    Add#(a__, TLog#(5), hbits),
    FShow#(Vector::Vector#(5, d)),
    Add#(1, b__, 4)
  );
  FilterFIFO#(d, 5) dut <- mkFilterFIFO;

  Reg#(Bit#(hbits)) w_row_cnt <- mkReg(0);
  Reg#(Bit#(wbits)) w_col_cnt <- mkReg(0);
  Reg#(Bit#(hbits)) r_row_cnt <- mkReg(0);
  Reg#(Bit#(wbits)) r_col_cnt <- mkReg(0);
  
  Reg#(Bit#(hbits)) rows <- mkReg(0);
  Reg#(Bit#(wbits)) cols <- mkReg(0);

  function Vector#(5, d) permute (Vector#(5, d) v);
      let vv = v;
      case (r_col_cnt)
        0:  case (r_row_cnt)
              0: vv = vector(v[2], v[1], v[0], v[1], v[2]);
              1: vv = vector(v[1], v[0], v[1], v[2], v[3]);
            endcase
        default: case (r_row_cnt)
              0: vv = vector(v[4], v[3], v[2], v[3], v[4]);   
              1: vv = vector(v[2], v[1], v[2], v[3], v[4]);
            endcase
      endcase
      
      case (r_col_cnt)
        (cols - 1): case (r_row_cnt)
          (rows - 2): vv = vector(v[1], v[2], v[3], v[4], v[3]);
          (rows - 1): vv = vector(v[2], v[3], v[4], v[3], v[2]);
        endcase
        default: case (r_row_cnt)
          (rows - 2): vv = vector(v[0], v[1], v[2], v[3], v[2]);
          (rows - 1): vv = vector(v[0], v[1], v[2], v[1], v[0]);
        endcase
      endcase
    return vv;
  endfunction

  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
    rows <= height;
    cols <= width;
  endmethod

  interface Put put;
    method Action put (d v);
      dut.enq(v);
      w_row_cnt <= (w_row_cnt == rows - 1) ? 0 : w_row_cnt + 1;
      w_col_cnt <= (w_row_cnt == rows - 1) ? ((w_col_cnt == cols - 1) ? 0 : w_col_cnt + 1) : w_col_cnt;
    endmethod
  endinterface

  interface Get get;
    method ActionValue#(Vector#(5, d)) get; 
      let v = dut.first;
        
      let vv = permute(v); 
      
      if (!(
        ((r_col_cnt == 0) && (r_row_cnt < 2)) ||
        ((r_col_cnt == cols - 1) && ((r_row_cnt >= rows - 2 - 1) && (r_row_cnt <= rows - 1)))
      )) begin 
        dut.deq;
      end else if ((r_col_cnt == cols - 1) && (r_row_cnt == rows - 1))
        dut.clear;


      r_row_cnt <= (r_row_cnt == rows - 1) ? 0 : r_row_cnt + 1;
      r_col_cnt <= (r_row_cnt == rows - 1) ? ((r_col_cnt == cols - 1) ? 0 : r_col_cnt + 1) : r_col_cnt;
      return vv;
    endmethod
  endinterface
endmodule
*/

/*
module mkSizedFilterFIFO2WithoutPermute (SizedFilterFIFO#(d, 2, hbits, wbits)) 
  provisos (
    Bits#(d, dsz),
    Add#(a__, TLog#(5), hbits),
    FShow#(Vector::Vector#(5, d)),
    Add#(1, b__, 4)
  );
  FilterFIFO#(d, 5) dut <- mkFilterFIFO;

  Reg#(Bit#(hbits)) w_row_cnt <- mkReg(0);
  Reg#(Bit#(wbits)) w_col_cnt <- mkReg(0);
  Reg#(Bit#(hbits)) r_row_cnt <- mkReg(0);
  Reg#(Bit#(wbits)) r_col_cnt <- mkReg(0);
  
  Reg#(Bit#(hbits)) rows <- mkReg(0);
  Reg#(Bit#(wbits)) cols <- mkReg(0);

  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
    rows <= height;
    cols <= width;
  endmethod

  interface Put put;
    method Action put (d v);
      dut.enq(v);
      w_row_cnt <= (w_row_cnt == rows - 1) ? 0 : w_row_cnt + 1;
      w_col_cnt <= (w_row_cnt == rows - 1) ? ((w_col_cnt == cols - 1) ? 0 : w_col_cnt + 1) : w_col_cnt;
    endmethod
  endinterface

  interface Get get;
    method ActionValue#(Vector#(5, d)) get; 
      let v = dut.first;
        
      let vv = v;
      
      if (!(
        ((r_col_cnt == 0) && (r_row_cnt < 2)) ||
        ((r_col_cnt == cols - 1) && ((r_row_cnt >= rows - 2 - 1) && (r_row_cnt <= rows - 1)))
      )) begin 
        dut.deq;
      end else if ((r_col_cnt == cols - 1) && (r_row_cnt == rows - 1))
        dut.clear;


      r_row_cnt <= (r_row_cnt == rows - 1) ? 0 : r_row_cnt + 1;
      r_col_cnt <= (r_row_cnt == rows - 1) ? ((r_col_cnt == cols - 1) ? 0 : r_col_cnt + 1) : r_col_cnt;
      return vv;
    endmethod
  endinterface
endmodule
*/
//---------------------------------------------------------------------------------

typedef enum {START_FRAME_0, START_FRAME_1, START_FRAME_2, PROCESS, END_FRAME_0, END_FRAME_1, END_FRAME_2, IDLE} FilterFIFO3State deriving (Bits, Eq);


module mkSizedFilterFIFO3WithFSM (SizedFilterFIFO#(d, 3, hbits, wbits)) 
  provisos (
    Bits#(d, dsz)
  );
  FilterFIFO#(d, 7) dut <- mkFilterFIFO;

  Reg#(Bit#(hbits)) w_row <- mkReg(0);
  Reg#(Bit#(wbits)) w_col <- mkReg(0);
  Reg#(Bit#(hbits)) r_row <- mkReg(0);
  Reg#(Bit#(wbits)) r_col <- mkReg(0);

  Reg#(Bit#(hbits)) rows <- mkReg(0);
  Reg#(Bit#(wbits)) cols <- mkReg(0);

  Reg#(FilterFIFO3State) state_r <- mkReg(START_FRAME_0);
  
  FIFO#(void) change_state_f <- mkFIFO;

  rule start_frame_0 (state_r == START_FRAME_0);
    dut.enq(?);
    state_r <= START_FRAME_1;
  endrule

  rule start_frame_1 (state_r == START_FRAME_1);
    dut.enq(?);
    state_r <= START_FRAME_2;
  endrule

  rule start_frame_2 (state_r == START_FRAME_2);
    dut.enq(?);
    state_r <= PROCESS;
  endrule
  
  rule end_frame_0 (state_r == END_FRAME_0);
    dut.enq(?);
    state_r <= END_FRAME_1;
  endrule

  rule end_frame_1 (state_r == END_FRAME_1);
    dut.enq(?);
    state_r <= END_FRAME_2;
  endrule

  rule end_frame_2 (state_r == END_FRAME_2);
    dut.enq(?);
    state_r <= IDLE;
  endrule

  rule change_state (state_r == IDLE);
    state_r <= START_FRAME_0;
    change_state_f.deq;
  endrule

  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
    rows <= height;
    cols <= width;
  endmethod

  interface Put put;
    method Action put (d v) if (state_r == PROCESS);
      dut.enq(v);
      w_row <= (w_row == rows - 1) ? 0 : w_row + 1;
      w_col <= (w_row == rows - 1) ? ((w_col == cols - 1) ? 0 : w_col + 1) : w_col;
      if ((w_col == cols - 1) && (w_row == rows - 1)) state_r <= END_FRAME_0;
    endmethod
  endinterface

  interface Get get;
    method ActionValue#(Vector#(7, d)) get; 
      let v = dut.first;
      //if ((r_col == cols - 1) && (r_row == rows - 1)) if (state_r != IDLE) $display("Error in filter fifo 3.");
      //if ((r_col == cols - 1) && (r_row == rows - 1) && (state_r == IDLE)) begin dut.clear; state_r <= START_FRAME_0; end else dut.deq;
      if ((r_col == cols - 1) && (r_row == rows - 1)) begin dut.clear; change_state_f.enq(?); end else dut.deq;
      if (r_row == 0) begin v[0] = v[6]; v[1] = v[5]; v[2] = v[4]; end
      if (r_row == 1) begin v[0] = v[4]; v[1] = v[3]; end
      if (r_row == 2) v[0] = v[2];

      if (r_row == rows - 3) v[6] = v[4];
      if (r_row == rows - 2) begin v[5] = v[3]; v[6] = v[2]; end
      if (r_row == rows - 1) begin v[6] = v[0]; v[5] = v[1]; v[4] = v[2]; end
       
      r_row <= (r_row == rows - 1) ? 0 : r_row + 1;
      r_col <= (r_row == rows - 1) ? ((r_col == cols - 1) ? 0 : r_col + 1) : r_col;
      return v;
    endmethod
  endinterface
endmodule


//---------------------------------------------------------------------------------


typedef enum {START_FRAME_0, START_FRAME_1, PROCESS, END_FRAME_0, END_FRAME_1, IDLE} FilterFIFOState deriving (Bits, Eq);

module mkSizedFilterFIFO2WithFSM (SizedFilterFIFO#(d, 2, hbits, wbits)) 
  provisos (
    Bits#(d, dsz)
  );
  FilterFIFO#(d, 5) dut <- mkFilterFIFO;

  Reg#(Bit#(hbits)) w_row <- mkReg(0);
  Reg#(Bit#(wbits)) w_col <- mkReg(0);
  Reg#(Bit#(hbits)) r_row <- mkReg(0);
  Reg#(Bit#(wbits)) r_col <- mkReg(0);

  Reg#(Bit#(hbits)) rows <- mkReg(0);
  Reg#(Bit#(wbits)) cols <- mkReg(0);

  Reg#(FilterFIFOState) state_r <- mkReg(START_FRAME_0);

  FIFO#(void) change_state_f <- mkFIFO;

  rule start_frame_0 (state_r == START_FRAME_0);
    dut.enq(?);
    state_r <= START_FRAME_1;
  endrule

  rule start_frame_1 (state_r == START_FRAME_1);
    dut.enq(?);
    state_r <= PROCESS;
  endrule
  
  rule end_frame_0 (state_r == END_FRAME_0);
    dut.enq(?);
    state_r <= END_FRAME_1;
  endrule

  rule end_frame_1 (state_r == END_FRAME_1);
    dut.enq(?);
    state_r <= IDLE;
  endrule

  rule change_state (state_r == IDLE);
    state_r <= START_FRAME_0;
    change_state_f.deq;
  endrule

  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
    rows <= height;
    cols <= width;
  endmethod

  interface Put put;
    method Action put (d v) if (state_r == PROCESS);
      dut.enq(v);
      w_row <= (w_row == rows - 1) ? 0 : w_row + 1;
      w_col <= (w_row == rows - 1) ? ((w_col == cols - 1) ? 0 : w_col + 1) : w_col;
      if ((w_col == cols - 1) && (w_row == rows - 1)) state_r <= END_FRAME_0;
    endmethod
  endinterface

  interface Get get;
    method ActionValue#(Vector#(5, d)) get; 
      let v = dut.first;
      //if ((r_col == cols - 1) && (r_row == rows - 1)) if (state_r != IDLE) $display("Error in filter fifo 2.");
      if ((r_col == cols - 1) && (r_row == rows - 1)) begin dut.clear; change_state_f.enq(?); end else dut.deq;

      if (r_row == 0) begin v[0] = v[4]; v[1] = v[3]; end
      if (r_row == 1) v[0] = v[2];
      if (r_row == rows - 2) v[4] = v[2];
      if (r_row == rows - 1) begin v[4] = v[0]; v[3] = v[1]; end
       
      r_row <= (r_row == rows - 1) ? 0 : r_row + 1;
      r_col <= (r_row == rows - 1) ? ((r_col == cols - 1) ? 0 : r_col + 1) : r_col;
      return v;
    endmethod
  endinterface
endmodule

(* synthesize *)
module mkTestSizedFilterFIFO2 (SizedFilterFIFO#(Bit#(16), 2, 11, 11));
  SizedFilterFIFO#(Bit#(16), 2, 11, 11) dut <- mkSizedFilterFIFO2WithFSM;
  return dut;
endmodule

module mkTbFilterFIFO2 (Empty);
  let dut <- mkTestSizedFilterFIFO2;

  let wcnt <- mkReg(0);
  let rcnt <- mkReg(0);
  let rows <- mkReg(9);
  let cols <- mkReg(5);
  let state <- mkReg(CONFIGURE);
  
  let pixels = rows * cols;

  rule configure (state == CONFIGURE);
    dut.set_image_size(rows, cols);
    state <= PROCESS;
  endrule
  
  rule write ((wcnt < pixels) && (state == PROCESS));
    $display("%t wr: (%d) %h", $time, wcnt, wcnt);
    dut.put.put(extend(wcnt));
    wcnt <= wcnt + 1;
  endrule

  rule read ((rcnt < pixels) && (state == PROCESS));
    let d <- dut.get.get;
    $display("%t rd: (%d) [%h %h  %h  %h %h]", $time, rcnt, d[4], d[3], d[2], d[1], d[0]);
    rcnt <= rcnt + 1;
  endrule

  rule stop ((rcnt >= pixels) && (state == PROCESS));
    $finish;
  endrule
endmodule


//------------------------------------------------------------------------------

// FIFO for 2n + 1 length filter

interface SizedFilterFIFO#(type d, numeric type n, numeric type hbits, numeric type wbits);
  interface Put#(d) put;
  interface Get#(Vector#(TAdd#(TMul#(n, 2), 1), d)) get;
  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
endinterface
/*
module mkSizedFilterFIFO (SizedFilterFIFO#(d, n, hbits, wbits)) 
  provisos (
    Bits#(d, dsz),
    NumAlias#(fsize, TAdd#(TMul#(n, 2), 1)),
    Add#(a__, TLog#(TAdd#(TMul#(n, 2), 1)), hbits),
    FShow#(Vector::Vector#(TAdd#(TMul#(n, 2), 1), d)),
    Add#(1, b__, TMul#(n, 2))
  );
  FilterFIFO#(d, fsize) dut <- mkFilterFIFO;

  Reg#(Bit#(hbits)) w_row_cnt <- mkReg(0);
  Reg#(Bit#(wbits)) w_col_cnt <- mkReg(0);
  Reg#(Bit#(hbits)) r_row_cnt <- mkReg(0);
  Reg#(Bit#(wbits)) r_col_cnt <- mkReg(0);
  
  Reg#(Bit#(hbits)) rows <- mkReg(0);
  Reg#(Bit#(wbits)) cols <- mkReg(0);

  function Vector#(fsize, d) permute (Vector#(fsize, d) in, Bit#(TLog#(fsize)) m, Bool fl, Bool boundary);
    Vector#(fsize, d) out;
    for (Integer i = 0; i < valueOf(fsize); i = i + 1) begin
      Bit#(TLog#(fsize)) j, jj, nn;
      j = fromInteger(i);
      nn = fromInteger(valueOf(n));
      jj = boundary ? 
     
      (fl ? (j <= 2*nn - m ? j + m : 2 * nn - j + 2*nn - m): 
            (j <= 2*nn - m ? j     : 2 * (2*nn - m) - j   )):

      (fl ? (j >= m ? j - m      : m - j         ):
            (j >= m ? j          : 2 * m - j     ));
      
      out[j] = in[jj];
    end
    return out;
  endfunction

  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
    rows <= height;
    cols <= width;
  endmethod

  interface Put put;
    method Action put (d v);
      dut.enq(v);
      w_row_cnt <= (w_row_cnt == rows - 1) ? 0 : w_row_cnt + 1;
      w_col_cnt <= (w_row_cnt == rows - 1) ? ((w_col_cnt == cols - 1) ? 0 : w_col_cnt + 1) : w_col_cnt;
    endmethod
  endinterface

  interface Get get;
    method ActionValue#(Vector#(fsize, d)) get; 
      let v = dut.first;
        
      let vv = r_row_cnt < fromInteger(valueOf(n)) ? 
                 permute(v, fromInteger(valueOf(n)) - truncate(r_row_cnt), r_col_cnt == 0, False) :
               r_row_cnt >= rows - fromInteger(valueOf(n)) ? 
                 permute(v, fromInteger(valueOf(n)) - truncate(rows - 1 - r_row_cnt), r_col_cnt == cols - 1, True):
               v;
    
      //$display("filterfifo col = %d of %d row = %d of %d", r_col_cnt, cols, r_row_cnt, rows);         
      //$display("filterfifo original ", fshow(v));
      //$display("filterfifo permuted ", fshow(vv));
      
      if (!(
        ((r_col_cnt == 0) && (r_row_cnt < fromInteger(valueOf(n)))) ||
        ((r_col_cnt == cols - 1) && ((r_row_cnt >= rows - fromInteger(valueOf(n)) -1) && (r_row_cnt <= rows - 1)))
      )) begin 
        dut.deq;
      end else if ((r_col_cnt == cols - 1) && (r_row_cnt == rows - 1))
        dut.clear;


      r_row_cnt <= (r_row_cnt == rows - 1) ? 0 : r_row_cnt + 1;
      r_col_cnt <= (r_row_cnt == rows - 1) ? ((r_col_cnt == cols - 1) ? 0 : r_col_cnt + 1) : r_col_cnt;
      return vv;
    endmethod
  endinterface
endmodule
*/

/*
(* synthesize *)
module mkTestSizedFilterFIFO (SizedFilterFIFO#(UInt#(16), 2, 11, 11));
  SizedFilterFIFO#(UInt#(16), 2, 11, 11) dut <- mkSizedFilterFIFO;
  return dut;
endmodule

module mkTbSizedFilterFIFO (Empty);
  let dut <- mkTestSizedFilterFIFO;

  let wcnt <- mkReg(0);
  let rcnt <- mkReg(0);
  let rows <- mkReg(9);
  let cols <- mkReg(5);
  let state <- mkReg(CONFIGURE);
  
  let pixels = rows * cols;

  rule configure (state == CONFIGURE);
    dut.set_image_size(rows, cols);
    state <= PROCESS;
  endrule
  
  rule write ((wcnt < pixels) && (state == PROCESS));
    $display("%t wr: (%d) %d", $time, wcnt, wcnt);
    dut.put.put(unpack(extend(wcnt)));
    wcnt <= wcnt + 1;
  endrule

  rule read ((rcnt < pixels) && (state == PROCESS));
    let d <- dut.get.get;
    $display("%t rd: (%d) ", $time, rcnt, fshow(d));
    rcnt <= rcnt + 1;
  endrule

  rule stop ((rcnt >= pixels) && (state == PROCESS));
    $finish;
  endrule
endmodule
*/

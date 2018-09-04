import GetPut::*;
import Vector::*;
import FIFO::*;

import AV::*;
import GetPutClientServer::*;

import FilterFIFO::*;
import SRAMTypes::*;
import TwoPRF::*;
import SRAMNames::*;


// Odd sized filter (enforced by the numeric types)
interface FIRFilterUpsampling#(numeric type n, numeric type dbits, numeric type hbits, numeric type wbits);
  interface Put#(Bit#(dbits)) put_pixel;
  interface Get#(Bit#(dbits)) get_pixel;
  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
endinterface


module mkFIRFilterUpsampling (
    function Bit#(dbits) apply_filter (Vector#(TAdd#(TMul#(2, n), 1), Bit#(dbits)) din), 
    function Vector#(TAdd#(TMul#(2, n), 1), Bit#(dbits)) rearrange (Vector#(TMul#(2, n), Bit#(dbits)) ds, Bit#(dbits) din, UInt#(TLog#(TMul#(2, n))) rotateby, Bit#(TLog#(TAdd#(TMul#(2, n), 1))) coltype),
    Integer maxheight,
    SizedFilterFIFO#(Bit#(dbits), n, hbits, wbits) row_buffer, 
    FIRFilterUpsampling#(n, dbits, hbits, wbits) ifc
  ) 
  provisos (
    Add#(a__, n, hbits), 
    Add#(b__, n, wbits),
    Add#(c__, TLog#(TAdd#(TMul#(n, 2), 1)), hbits),
    Add#(d__, TLog#(TAdd#(TMul#(2, n), 1)), wbits),
    Add#(e__, TLog#(TMul#(2, n)), wbits),
    Add#(1, f__, TMul#(n, 2))
  );
  
  //  2 * n + 1 point filter
  
  Vector#(n, SRAM#(Bit#(hbits), dbits)) col_buffer <- 
    replicateM(mkTwoPRF(upsampling_buffer_name(maxheight), maxheight));
 

  let write_f <- mkFIFO;
  let buf_f <- mkFIFO;
  let inter_f <- mkFIFO;
  let dout_f <- mkFIFO;

  Vector#(3, Reg#(Bit#(hbits))) row <- replicateM(mkReg(0));
  Vector#(3, Reg#(Bit#(wbits))) col <- replicateM(mkReg(0));
  Reg#(Bit#(hbits)) rows <- mkReg(0);
  Reg#(Bit#(wbits)) cols <- mkReg(0);
  
  
  Bit#(wbits) nv = fromInteger(valueOf(n));

  // ---------------------------------------------------------------------------
  // Functions
  // ---------------------------------------------------------------------------

  function Action incr_row_col (Reg#(Bit#(hbits)) row_r, Reg#(Bit#(wbits)) col_r) = action
    row_r <= (row_r == rows - 1) ? 0 : row_r + 1;
    col_r <= (row_r == rows - 1) ? ((col_r == cols - 1 + nv) ? 0 : col_r + 1) : col_r;  
  endaction;


  // ---------------------------------------------------------------------------
  // Rules
  // ---------------------------------------------------------------------------

  rule permute_cols (cols > 0);
    if (col[0] < cols) begin
      let din <- row_buffer.get.get;
      buf_f.enq(din);
    end
    incr_row_col(row[0], col[0]);
  endrule


  rule filter_columns (cols > 0);
    let dout = 0;
    
    if (col[1] < cols) begin
      let din <- get(buf_f);
      //let din <- row_buffer.get.get;
      dout = apply_filter(din);
    end

    if (col[1] > nv - 1) 
      for (Integer i = 0; i < valueOf(n); i = i + 1) 
        col_buffer[i].rserver <= row[1];   
  
    write_f.enq(dout);

    incr_row_col(row[1], col[1]);
  endrule


  rule permute_rows;
    
    let d <- get(write_f);

    if (col[2] < cols) begin
      if (col[2][0] == 0) begin
        col_buffer[(col[2]/2) % fromInteger(valueOf(n))].wput <= wreq(extend(row[2]), pack(d));
      end
    end

    if (col[2] > nv - 1) begin 
      Vector#(TMul#(2, n), Bit#(dbits)) ds;
      for(Integer i = 0; i < valueOf(TMul#(2, n)); i = i + 1) 
        ds[i] = 0;
      for(Integer i = 0; i < valueOf(n); i = i + 1) 
        ds[2*i] <- liftAV(unpack, col_buffer[i].rserver);  

      let coltype = truncate(
        col[2] < 2 * nv ? 
          col[2] - nv : 
        (col[2] >= cols ? 
          cols + nv - col[2] + nv - 1 : 
          fromInteger(valueOf(TMul#(2, n)))));
      
      let rotateby = unpack(truncate((col[2]) % fromInteger(valueOf(TMul#(2,n)))));
      
      let inter = rearrange(ds, d, rotateby, coltype);
      inter_f.enq(inter);
    end

    incr_row_col(row[2], col[2]);
  endrule


  rule filter_rows;
    let inter <- get(inter_f);
    let dout = apply_filter(inter);
    dout_f.enq(dout);
  endrule


  // ---------------------------------------------------------------------------
  // Methods
  // ---------------------------------------------------------------------------

  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
    rows <= height;
    cols <= width;
    row_buffer.set_image_size(height, width);
  endmethod

  interface Put put_pixel;
    method Action put (Bit#(dbits) v) if ((rows > 0) && (cols > 0));
      row_buffer.put.put(v);
    endmethod
  endinterface

  interface Get get_pixel;
    method ActionValue#(Bit#(dbits)) get if ((rows > 0) && (cols > 0));
      let dout <- get(dout_f);
      return dout;
    endmethod
  endinterface

endmodule

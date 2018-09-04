//`define SYNTHESIS
//import Standard::*;
import FIFO::*;
import RegFile::*;
import GetPut::*;
import Vector::*;

import GetPutClientServer::*;
import Trace::*;
import VectorOps::*;
import MiscFunctions::*;

import FilterFIFO::*;
import FIRFilterDownsampling::*;
import FIRFilterUpsampling::*;
import SRAMTypes::*;
import TwoPRF::*;
import SRAMFIFO::*;
import SRAMNames::*;
import PyramidFuncs::*;

interface PyramidLevel#(numeric type dbits, numeric type hbits, numeric type wbits);
  interface Put#(Bit#(dbits)) put_pixel;
  interface Get#(Bit#(dbits)) get_pixel;
  interface Get#(Vector#(3, Int#(TAdd#(dbits, 1)))) get_riesz;
  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
endinterface

interface PyramidConstructor#(numeric type dbits, numeric type maxheight, numeric type maxwidth);
  interface Put#(Bit#(dbits)) put_pixel;
  interface Get#(Bit#(dbits)) get_lowpass_pixel;
  interface Get#(Tuple2#(Vector#(3, Int#(TAdd#(dbits, 1))), Bit#(TLog#(TSub#(TLog#(maxheight), 5))))) get_riesz;
  method Action set_image_size (Bit#(TLog#(maxheight)) height, Bit#(TLog#(maxwidth)) width);
endinterface


module mkPyramidConstructor (PyramidConstructor#(dbits, maxh, maxw) ifc)
  provisos (
    NumAlias#(hbits, TLog#(maxh)),
    NumAlias#(levels, TSub#(hbits, 4)),
    NumAlias#(wbits, TLog#(maxw)),
    Add#(a__, 2, hbits),
    Add#(b__, 2, wbits),
    Add#(c__, 3, hbits),
    Add#(d__, 3, wbits),
    Add#(5, e__, TLog#(maxh))
  );
  
  let pixel_f <- mkGPFIFO;
  let riesz_f <- mkGPFIFO;
  let lowpass_f <- mkGPFIFO;
  Vector#(levels, FIFO#(Tuple2#(Bit#(hbits), Bit#(wbits)))) size_f <- replicateM(mkFIFO);

  let rows <- mkReg(0);
  let cols <- mkReg(0);
 

  module mkPyramidLevel (Integer maxheight, PyramidLevel#(dbits, hbits, wbits) ifc);

    Vector#(3, Reg#(Bit#(hbits))) row_cnt <- replicateM(mkReg(0));
    Vector#(3, Reg#(Bit#(wbits))) col_cnt <- replicateM(mkReg(0));
    
    SizedFilterFIFO#(Bit#(dbits), 2, hbits, wbits) df_row_buffer <- mkSizedFilterFIFO2WithFSM; //mkSizedFilterFIFO2WithoutPermute;
    SizedFilterFIFO#(Bit#(dbits), 2, hbits, wbits) uf_row_buffer <- mkSizedFilterFIFO2WithFSM; //mkSizedFilterFIFO2WithoutPermute;
    
    FIRFilterDownsampling#(2, dbits, hbits, wbits) dfilter <- mkFIRFilterDownsampling(pyr_apply_filter, pyr_rearrange, maxheight, df_row_buffer);
    FIRFilterUpsampling#(2, dbits, hbits, wbits) ufilter <- mkFIRFilterUpsampling(pyr_apply_filter, pyr_rearrange, maxheight, uf_row_buffer);
    
    `ifdef SYNTHESIS
    TSMC_2PRF_ifc#(Bit#(TAdd#(hbits, 2)), dbits) pixel_buffer <- tsmc_2prf(luminance_buffer_name(maxheight), maxheight * 4);
    `else
    TSMC_2PRF_ifc#(Bit#(TAdd#(hbits, 2)), dbits) pixel_buffer <- sim_2prf(maxheight * 4);
    `endif
    FIFO#(Bit#(dbits)) pixel_fifo <- mkSRAMFIFO_2p(pixel_buffer, maxheight * 4);
    
    Vector#(2, SRAM#(Bit#(hbits), TAdd#(dbits, 1))) laplacian_buffer <- replicateM(mkTwoPRF(laplacian_buffer_name(maxheight), maxheight));

    FIFO#(Int#(TAdd#(dbits, 1))) laplacian_f <- mkFIFO;
    FIFO#(Int#(TAdd#(dbits, 1))) r1_f <- mkSizedFIFO(8);
    SizedFilterFIFO1#(Int#(TAdd#(dbits, 1)), hbits, wbits) r2_f <- mkSizedFilterFIFO1;
    let dsmpl_f <- mkFIFO;
    
    let rows <- mkReg(0);
    let cols <- mkReg(0);
 
    rule upsample;
      let d <- dfilter.get_pixel.get;
      let even_row_col = ((row_cnt[0][0] == 1'b0) && (col_cnt[0][0] == 1'b0));
      if(even_row_col) dsmpl_f.enq(d);
      ufilter.put_pixel.put(even_row_col ? d : 0);
      row_cnt[0] <= incr_row(row_cnt[0], rows);
      col_cnt[0] <= incr_col(col_cnt[0], cols, row_cnt[0], rows);
    endrule

    rule compute_laplacian ((rows > 0) && (cols > 0));
      if (col_cnt[1] < cols) begin
        let lowpass_pixel <- ufilter.get_pixel.get;
        let pixel = pixel_fifo.first;
        pixel_fifo.deq;
        Int#(TAdd#(dbits, 1)) laplacian = unpack(extend(pixel)) - unpack(extend(4*lowpass_pixel));
        laplacian_f.enq(laplacian);
      end
      if(col_cnt[1] > 0) begin 
        for (Integer i = 0; i < 2; i = i + 1) laplacian_buffer[i].rserver <= row_cnt[1];   
      end
      row_cnt[1] <= incr_row(row_cnt[1], rows);
      col_cnt[1] <= incr_col(col_cnt[1], cols + 1, row_cnt[1], rows);
    endrule

    rule write_laplacian ((rows > 0) && (cols > 0));
      let left = 0, middle = 0, right = 0;
      if (col_cnt[2] < cols) begin
        right <- get(laplacian_f);
        laplacian_buffer[col_cnt[2][0]].wput <= wreq(row_cnt[2], pack(right));
      end
      if (col_cnt[2] > 0) begin
        middle <- laplacian_buffer[~col_cnt[2][0]].rserver;
        left <- laplacian_buffer[col_cnt[2][0]].rserver;
        if ((col_cnt[2] == 1) || (col_cnt[2] == cols)) left = pack(right);

        //trace("r1 first", right);
        //trace("r1 second", left);
        
        Int#(TAdd#(2, dbits)) r1 = extend(right) - extend(unpack(left));
        r1_f.enq(truncate(r1 >> 1));
        r2_f.put.put(unpack(middle));
      end
      row_cnt[2] <= incr_row(row_cnt[2], rows);
      col_cnt[2] <= incr_col(col_cnt[2], cols + 1, row_cnt[2], rows);
    endrule

    let riesz_components_f <- mkFIFO;

    rule get_riesz_components;
        let r1 <- get(r1_f);
        let r2_in <- r2_f.get.get;
        riesz_components_f.enq(tuple2(r1, r2_in));
    endrule

    method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
      dfilter.set_image_size(height, width);
      ufilter.set_image_size(height, width);
      r2_f.set_image_size(height, width);
      rows <= height;
      cols <= width;
    endmethod
   
    interface Put put_pixel;
      method Action put (Bit#(dbits) d);
        dfilter.put_pixel.put(d);     
        pixel_fifo.enq(d);
      endmethod
    endinterface

    interface Get get_pixel;
      method ActionValue#(Bit#(dbits)) get;
        dsmpl_f.deq;
        return dsmpl_f.first;
      endmethod
    endinterface

    interface Get get_riesz;
      method ActionValue#(Vector#(3, Int#(TAdd#(1, dbits)))) get;
        let {r1, r2_in} <- get(riesz_components_f);
        //trace("r2 first", r2_in[2]);
        //trace("r2 second", r2_in[0]);
        Int#(TAdd#(2, dbits)) r2 = extend(r2_in[2]) - extend(r2_in[0]);
        return vector(r2_in[1], r1, truncate(r2 >> 1));
      endmethod
    endinterface
  endmodule

  Reg#(Bit#(TLog#(levels))) real_levels <- mkReg(0);

  Vector#(levels, PyramidLevel#(dbits, hbits, wbits)) pyrlevel;
  Integer j = valueOf(maxh);
  for (Integer i = 0; i < valueOf(levels); i = i + 1) begin
    pyrlevel[i] <- mkPyramidLevel(j);
    j = (j + 1)/2;
  end


  rule feed_pyramid_0;
    let d <- tpl_1(pixel_f).get;
    pyrlevel[0].put_pixel.put(d);
  endrule
  

  Vector#(levels, Rules) feed_rules;
  for (Integer i = 0; i < valueOf(levels); i = i + 1) begin
    feed_rules[i] = (rules
      rule feed_pyramid (fromInteger(i) < real_levels);
          
        let d <- pyrlevel[i].get_pixel.get;
        
        if (fromInteger(i) == real_levels - 1)
          tpl_2(lowpass_f).put(d);
        else if (i < valueOf(TSub#(levels, 1)))
          pyrlevel[i + 1].put_pixel.put(d);
      
      endrule
    endrules);
  end
  addRules(foldl1(rJoinConflictFree, feed_rules));


  //---------------------------------------------------------------------------------------------
  //  Stream out riesz values from each pyramid level with higher priority to lower resolutions
  //---------------------------------------------------------------------------------------------

  Vector#(levels, Rules) stream_rules;
  for (Integer i = 0; i < valueOf(levels); i = i + 1) begin
    stream_rules[i] = (rules
      rule stream_pyramid;
        if (fromInteger(i) < real_levels) begin
          let d <- pyrlevel[i].get_riesz.get;
          tpl_2(riesz_f).put(tuple2(d, fromInteger(i)));
        end
      endrule
    endrules);
  end
  addRules(foldl1(rJoinDescendingUrgency, stream_rules));


  //----------------------------------------
  //  Set image size at each pyramid level
  //----------------------------------------

  Vector#(levels, Rules) set_size_rules;
  for (Integer i = 0; i < valueOf(levels); i = i + 1) begin
    set_size_rules[i] = (rules
      rule set_pyrlevel_image_size;
        let {h, w} <- get(size_f[i]);
        if ((h > 20) && (w > 20)) begin
          pyrlevel[i].set_image_size(h, w);
          if (i != valueOf(levels) - 1) size_f[i + 1].enq(tuple2((h + 1)/2, (w + 1)/2));
          real_levels <= fromInteger(i + 1);
        end
      endrule
    endrules);
  end
  addRules(foldl1(rJoinMutuallyExclusive, set_size_rules));


  method Action set_image_size (Bit#(hbits) height, Bit#(wbits) width);
    Bit#(hbits) h = height; 
    Bit#(wbits) w = width;
    
    rows <= h;
    cols <= w;

    size_f[0].enq(tuple2(h, w));
  endmethod


  interface put_pixel = tpl_2(pixel_f);
  interface get_lowpass_pixel = tpl_1(lowpass_f);
  interface get_riesz = tpl_1(riesz_f);
endmodule


//----------------
//  Test Module
//----------------


typedef 16 DataBits;
//typedef 1080 MaxHeight;
//typedef 1920 MaxWidth;
typedef 720 MaxHeight;
typedef 1280 MaxWidth;


typedef enum {CONFIGURE, PROCESS} State deriving (Bits, Eq);

(* synthesize *)
module mkPyramidConstructorInst (PyramidConstructor#(DataBits, MaxHeight, MaxWidth));
  PyramidConstructor#(DataBits, MaxHeight, MaxWidth) pyr <- mkPyramidConstructor();
  return pyr;
endmodule

typedef 540 Rows;
typedef 720 Cols;
typedef 8   Frames;
typedef Bit#(TLog#(TMul#(TMul#(Rows, Cols), Frames))) RegFileAddr;

module mkTbPyramidConstructor (Empty);
  
  let dut <- mkPyramidConstructorInst;

  let frames = fromInteger(valueOf(Frames));
  let rows = fromInteger(valueOf(Rows));
  let cols = fromInteger(valueOf(Cols));
  Vector#(6, RegFileAddr) pixels = vector(388800, 97200, 24300, 6120, 1530, 391);


  RegFile#(RegFileAddr, Vector#(3, Int#(32))) ifile <- mkRegFileLoad("test_vectors/pyr_in_luminance.dat", 0, pixels[0]*frames - 1);//
  RegFile#(RegFileAddr, Vector#(5, Int#(32))) ofile_0 <- mkRegFileLoad("test_vectors/pyr_out_0.dat", 0, pixels[0]*frames - 1);//
  RegFile#(RegFileAddr, Vector#(5, Int#(32))) ofile_1 <- mkRegFileLoad("test_vectors/pyr_out_1.dat", 0, pixels[1]*frames - 1);//
  RegFile#(RegFileAddr, Vector#(5, Int#(32))) ofile_2 <- mkRegFileLoad("test_vectors/pyr_out_2.dat", 0, pixels[2]*frames - 1);//
  RegFile#(RegFileAddr, Vector#(5, Int#(32))) ofile_3 <- mkRegFileLoad("test_vectors/pyr_out_3.dat", 0, pixels[3]*frames - 1);//
  RegFile#(RegFileAddr, Vector#(5, Int#(32))) ofile_4 <- mkRegFileLoad("test_vectors/pyr_out_4.dat", 0, pixels[4]*frames - 1);//
  RegFile#(RegFileAddr, Vector#(3, Int#(32))) ofile_5 <- mkRegFileLoad("test_vectors/pyr_out_5.dat", 0, pixels[5]*frames - 1);//

  let feed_count <- mkReg(0);
  Vector#(5, Reg#(RegFileAddr)) stream_count <- replicateM(mkReg(0));
  Reg#(State) state <- mkReg(CONFIGURE);

  rule configure (state == CONFIGURE);
    dut.set_image_size(rows, cols);
    state <= PROCESS;
  endrule

  rule feed ((state == PROCESS) && (feed_count < pixels[0]*frames));
    let d = ifile.sub(feed_count);
    trace("feed_count", feed_count);
    trace("input pixel", d[0]);
    dut.put_pixel.put(pack(truncate(d[0] << 8)));
    incr(feed_count, 1);
  endrule

  let lowpass_count <- mkReg(0);
  
  rule stream_lowpass (state == PROCESS);
    let out <- dut.get_lowpass_pixel.get;
    let exp = ofile_5.sub(lowpass_count);
    trace("lowpass_count", lowpass_count);
    trace("exp lowpass", pack(exp[0]));
    trace("out lowpass", pack(out));
    if (out != truncate(pack(exp[0]))) begin
      $display("FAILED");
      $finish;
    end
    incr(lowpass_count, 1);
  endrule
  
  rule stream (state == PROCESS);
    let out <- dut.get_riesz.get;
    let val = tpl_1(out);
    let tag = tpl_2(out);


    let exp = case (tag)
    0: ofile_0.sub(stream_count[0]);
    1: ofile_1.sub(stream_count[1]);
    2: ofile_2.sub(stream_count[2]);
    3: ofile_3.sub(stream_count[3]);
    4: ofile_4.sub(stream_count[4]);
    endcase;

    Vector#(3, Int#(TAdd#(DataBits, 1))) triplet = vector(truncate(exp[2]), truncate(exp[1]), truncate(exp[0]));
    
    incr(stream_count[tag], 1);   
     
    trace("stream_count", stream_count[tag]);
    trace("col", exp[4]);
    trace("row", exp[3]);
    trace("val", val);
    trace("tag", tag);
    trace("exp", triplet); 
    
    if(val != triplet) begin
      $display("FAILED");
      $finish;
    end
    
    if(
      (stream_count[0] == pixels[0]*frames) &&
      (stream_count[1] == pixels[1]*frames) &&
      (stream_count[2] == pixels[2]*frames) &&
      (stream_count[3] == pixels[3]*frames) &&
      (stream_count[4] == pixels[4]*frames-1) 
    )
    begin
      $display("PASSED");
      $finish;
    end
  endrule

endmodule

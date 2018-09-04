//`define SYNTHESIS
import Clocks::*;
import RegFile::*;
import FIFO::*;

import AReg::*;

import SRAMTypes::*;

export TwoPRF::*;
export SRAMTypes::*;

// Verilog interface of TSMC's 2PRF
interface TSMC_2PRF_ifc#(type taddr, numeric type dsz);
    method Action write(taddr waddr, Bit#(dsz) wdata, Bit#(dsz) bwe);
    method Action read(taddr raddr);
    method Bit#(dsz) rdata;
endinterface

// Although TSMC provides 2PRF with separate clocks, we don't use them
import "BVI" module tsmc_2prf (String vlogname, Integer depth, TSMC_2PRF_ifc#(taddr, dsz) ifc)
    provisos(Bits#(taddr, taddr_sz), Literal#(taddr));
    parameter DATA_WIDTH = valueOf(dsz);
    parameter ADDR_WIDTH  = valueOf(SizeOf#(taddr));
    parameter VLOG_NAME = vlogname;  
    parameter DEPTH = depth;

    method read(raddr) enable (re);
    method rdata rdata();
    method write(waddr, wdata, bwe) enable (we);

    default_clock clk(clk);
    default_reset no_reset;

    schedule (rdata) SB (read);
    schedule (rdata) CF (rdata, write);
    schedule (write) CF (read);
    // Compiler assumes conflict by default. But to make it explicit:
    schedule (read) C (read);
    schedule (write) C (write);
endmodule

// BSV model of the above SRAM
module sim_2prf_buggy (Integer depth, TSMC_2PRF_ifc#(taddr, dsz) ifc)
    provisos(Bits#(taddr, taddr_sz), Literal#(taddr), Eq#(taddr));
    RegFile#(taddr, Bit#(dsz)) mem <- mkRegFile(0, fromInteger(depth-1));
    let dout <- mkRegU;
    let raddr_w <- mkWire();
    let waddr_w <- mkWire();

    let rconflict_wire <- mkPulseWire();
    let wconflict_wire <- mkPulseWire();

    rule contention_check;
        if (raddr_w == waddr_w) begin
            $display("ERROR! Time:%t Address contention at %b in %m", $stime, raddr_w);
        end
    endrule
    
    method write(waddr, wdata, bwe) = action
        wconflict_wire.send();
        mem.upd(waddr, (mem.sub(waddr) & ~bwe) | (wdata & bwe));
        waddr_w <= waddr;
    endaction;

    method read(raddr) = action
        rconflict_wire.send();
        dout <= mem.sub(raddr);
        raddr_w <= raddr;
    endaction;

    method rdata = dout;
endmodule

// Module with safe read interface
module mkTwoPRF(String vlogname, Integer depth, SRAM#(taddr, dsz) ifc)
    provisos(Bits#(taddr, taddr_sz), Literal#(taddr), Eq#(taddr));
    //TSMC_2PRF_ifc#(taddr, dsz) twoprf 
    //  <- genVerilog? tsmc_2prf(vlogname): sim_2prf(depth);
    `ifdef SYNTHESIS
    TSMC_2PRF_ifc#(taddr, dsz) twoprf <- tsmc_2prf(vlogname, depth);
    `else
    TSMC_2PRF_ifc#(taddr, dsz) twoprf <- sim_2prf(depth);
    `endif
    
    FIFO#(void) dout_f <- mkLFIFO;

    interface AReg rserver;
        method _write(raddr) = action
            twoprf.read(raddr);
            dout_f.enq(?);
            //$display("%m SRAM read at addr = %d", raddr);
        endaction;

        method _read = actionvalue
            dout_f.deq;
            return twoprf.rdata;
        endactionvalue;
    endinterface

    interface Write wput;
        method _write(write_req) = action
            let {addr, data, bwe, wt} = write_req;
            //$display("%m SRAM write at addr %d data %d", addr, data);
            twoprf.write(addr, data, bwe);
             if (wt == True) begin
                 $display("ERROR! TSMC 2PRF does not support write-through");
                 $finish;
             end
        endaction;
    endinterface
endmodule

// BSV model of TSMC's TwoPRF
module sim_2prf (Integer depth, TSMC_2PRF_ifc#(taddr, dsz) ifc)
    provisos(Bits#(taddr, taddr_sz), Literal#(taddr), Eq#(taddr));
    RegFile#(taddr, Bit#(dsz)) mem <- mkRegFile(0, fromInteger(depth-1));

//module sim_twoprf (module#(RegFile#(Bit#(asize), Bit#(dsize))) mkRF, TSMC_TwoPRF#(asize, dsize) ifc);
//  let mem ← mkRF;
  let dout <- mkRegU;
  RWire#(taddr) raddr_w <- mkRWire;
  RWire#(Tuple3#(taddr, Bit#(dsz), Bit#(dsz))) waddr_w <- mkRWire;

  (* no_implicit_conditions, fire_when_enabled *)
  rule bookkeep;
    if (waddr_w.wget matches tagged Valid .wadb) begin
      let {waddr, wdata, bweb} = wadb;
      let new_data = (mem.sub(waddr) & bweb) | (wdata & ~bweb);
      mem.upd(waddr, unpack(new_data));

      if (raddr_w.wget == tagged Valid waddr) begin
        $display("ERROR! At time:%t, address contention at %b in %m", $stime, waddr);
      end
    end

    if (raddr_w.wget matches tagged Valid .raddr) begin
      dout <= mem.sub(raddr);
    end
  endrule

  method write(waddr, wdata, bwe)
  = waddr_w.wset(tuple3(waddr, wdata, ~bwe));

  method read = raddr_w.wset;

  method rdata = dout;
endmodule


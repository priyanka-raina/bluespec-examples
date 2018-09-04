import RegFile::*;
import FIFO::*;

import AReg::*;

import SRAMTypes::*;
//import Standard::*;

export SPSRAM::*;
export SRAMTypes::*;

// Verilog interface of TSMC's SPSRAM
interface TSMC_SPSRAM_ifc#(type taddr, numeric type dsz);
    method Action put(Bool rnw, taddr addr, Bit#(dsz) datai,
                      Bit#(dsz) bwe, Bool wt);

    method Bit#(dsz) rdata;
endinterface

import "BVI" module tsmc_spsram(String vlogname, TSMC_SPSRAM_ifc#(taddr, dsz) ifc)
    provisos(Bits#(taddr, taddr_sz));
    parameter DATA_WIDTH = valueOf(dsz);
    parameter ADDR_WIDTH = valueOf(taddr_sz);
    parameter VLOG_NAME = vlogname;

    method put(rnw, addr, datai, bwe, wt) enable (cs);
    method datao rdata();

    default_clock clk(clk);
    default_reset no_reset;

    schedule (rdata) SB (put);
    schedule (rdata) CF (rdata);
    schedule (put) C (put);
endmodule

// BSV model of the above SRAM
module sim_spsram (Integer depth, TSMC_SPSRAM_ifc#(taddr, dsz) ifc)
    provisos(Bits#(taddr, taddr_sz), Literal#(taddr));
    RegFile#(taddr, Bit#(dsz)) mem <- mkRegFile(0, fromInteger(depth-1));
    let dout <- mkRegU;
    function mask(a, b, bwe) = (a & ~bwe) | (b & bwe);
    let conflict_wire <- mkPulseWire;

    method put(rnw, addr, datai, bwe, wt) = action
        conflict_wire.send();
        if(rnw) begin
            dout <= mem.sub(addr);
        end
        else begin
            mem.upd(addr, mask(mem.sub(addr), datai, bwe));
            if(wt) dout <= mask(dout, datai, bwe);
        end
    endaction;

    method rdata = dout;
endmodule

// Creates a module with a safe SRAM read interface.
module mkSPSRAM(String vlogname, Integer depth, SRAM#(taddr, dsz) ifc)
    provisos(Bits#(taddr, taddr_sz), Literal#(taddr));
    TSMC_SPSRAM_ifc#(taddr, dsz) spsram 
      <- genVerilog? tsmc_spsram(vlogname): sim_spsram(depth);
    FIFO#(void) dout_f <- mkLFIFO;

    interface AReg rserver;
        method _read = actionvalue
            dout_f.deq;
            return spsram.rdata;
        endactionvalue;

        method _write(raddr) = action
            spsram.put(True, raddr, ?, ?, False);
            dout_f.enq(?);
        endaction;
    endinterface
    
    interface Write wput;
        method _write(write_req) = action
            let {addr, data, bwe, wt} = write_req;
            spsram.put(False, addr, data, bwe, wt);
        endaction;
    endinterface
endmodule

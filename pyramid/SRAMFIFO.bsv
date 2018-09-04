import FIFO::*;

import Trace::*;
import ListOps::*;

import TwoPRF::*;
import SPSRAM::*;

// FIFO depth is SRAM depth + 1 because SRAM has registered output
// Writing to sram given higher priority than read
module mkSRAMFIFO_sp_enq(TSMC_SPSRAM_ifc#(taddr, tdata_sz) sram,
                         Integer depth, FIFO#(tdata) ifc)
    provisos (Bits#(tdata, tdata_sz),
              Arith#(taddr), FShow#(taddr), Eq#(taddr),
              Bits#(taddr, taddr_sz));

    let max = fromInteger(depth - 1);
    function inc(x) = (x == max)? 0: x + 1;
    function dec(x) = (x == 0)? max: x - 1;

    List#(String) tags = list("rptr", "wptr", "srfull", "rdvalid");
    function tr = traceIn(tags);

    Reg#(taddr) rptr <- mkReg(0);
    Reg#(taddr) wptr <- mkReg(0);
    Reg#(Bool) sramfull <- mkReg(False); // to distinguish wraparound
    Reg#(Bool) rdvalid <- mkReg(False);
    Bool sramempty = (rptr == wptr) && !sramfull;

    RWire#(tdata) enq_w <- mkRWire;
    let deq_w <- mkPulseWire;

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_stuff;
        //tr("rptr", rptr);
        //tr("wptr", wptr);
        //tr("srfull", sramfull);
        //tr("rdvalid", rdvalid);

        let writing = False;
        let reading = False;
        let wt = False;

        if (enq_w.wget matches tagged Valid .d) begin
            // use write-through when sram is empty and registered output
            // is invalid or about to be dequeued
            wt = (rptr == wptr) && (deq_w || !rdvalid);
            sram.put(False, wptr, pack(d), '1, wt);
            writing = !wt; // If wt, no need to increment wptr
        end
        else if ((deq_w || !rdvalid) && !sramempty)  begin
            sram.put(True, rptr, ?, ?, ?);
            reading = True;
        end

        if (reading) rptr <= inc(rptr);
        if (writing) wptr <= inc(wptr);
        case (tuple2(reading, writing)) matches
            // Going out of overflow state on deq
            {True, False}: if (rptr == wptr) sramfull <= False;
            // Entering overflow state on enq
            {False, True}: if (rptr == inc(wptr)) sramfull <= True;
        endcase

        // valid data to appear at output next cycle
        if (reading || wt) rdvalid <= True;
        // registered data being invalidated
        else if (deq_w) rdvalid <= False;
    endrule

    method enq(din) = when(!sramfull, enq_w.wset(din));
    method first = when(rdvalid, unpack(sram.rdata));
    method deq = when(rdvalid, deq_w.send);

    method clear = action
        rptr <= 0;
        wptr <= 0;
        sramfull <= False;
        rdvalid <= False;
    endaction;
endmodule

// FIFO depth is SRAM depth + 1 because SRAM has registered output
// Reading from sram given higher priority than writing
module mkSRAMFIFO_sp_deq(TSMC_SPSRAM_ifc#(taddr, tdata_sz) sram,
                         Integer depth, FIFO#(tdata) ifc)
    provisos (Bits#(tdata, tdata_sz),
              Arith#(taddr), FShow#(taddr), Eq#(taddr),
              Bits#(taddr, taddr_sz));

    let max = fromInteger(depth - 1);
    function inc(x) = (x == max)? 0: x + 1;
    function dec(x) = (x == 0)? max: x - 1;

    List#(String) tags = list("rptr", "wptr", "srfull", "rdvalid");
    function tr = traceIn(tags);

    Reg#(taddr) rptr <- mkReg(0);
    Reg#(taddr) wptr <- mkReg(0);
    Reg#(Bool) sramfull <- mkReg(False); // to distinguish wraparound
    Reg#(Bool) rdvalid <- mkReg(False);
    Bool sramempty = (rptr == wptr) && !sramfull;

    RWire#(tdata) enq_w <- mkRWire;
    let deq_w <- mkPulseWire;

    Bool do_sram_read = (deq_w || !rdvalid) && !sramempty;
    (* no_implicit_conditions, fire_when_enabled *)
    rule do_stuff;
        //tr("rptr", rptr);
        //tr("wptr", wptr);
        //tr("srfull", sramfull);
        //tr("rdvalid", rdvalid);

        let writing = False;
        let reading = False;
        let wt = False;

        if (do_sram_read)  begin
            sram.put(True, rptr, ?, ?, ?);
            reading = True;
        end
        else if (enq_w.wget matches tagged Valid .d) begin
            // use write-through when sram is empty and registered output
            // is invalid or about to be dequeued
            wt = (rptr == wptr) && (deq_w || !rdvalid);
            sram.put(False, wptr, pack(d), '1, wt);
            writing = !wt; // If wt, no need to increment wptr
        end

        if (reading) rptr <= inc(rptr);
        if (writing) wptr <= inc(wptr);
        case (tuple2(reading, writing)) matches
            // Going out of overflow state on deq
            {True, False}: if (rptr == wptr) sramfull <= False;
            // Entering overflow state on enq
            {False, True}: if (rptr == inc(wptr)) sramfull <= True;
        endcase

        // valid data to appear at output next cycle
        if (reading || wt) rdvalid <= True;
        // registered data being invalidated
        else if (deq_w) rdvalid <= False;
    endrule

    method enq(din) = when(!do_sram_read && !sramfull, enq_w.wset(din));
    method first = when(rdvalid, unpack(sram.rdata));
    method deq = when(rdvalid, deq_w.send);

    method clear = action
        rptr <= 0;
        wptr <= 0;
        sramfull <= False;
        rdvalid <= False;
    endaction;
endmodule

// FIFO depth is SRAM depth + 1 because SRAM has registered output
// FIFO wrapper around 2PRF
module mkSRAMFIFO_2p(TSMC_2PRF_ifc#(taddr, tdata_sz) sram, Integer depth,
                     FIFO#(tdata) ifc)
    provisos(Bits#(tdata, tdata_sz),
              Arith#(taddr), FShow#(taddr), Eq#(taddr), Ord#(taddr),
              Bits#(taddr, taddr_sz));

    let max = fromInteger(depth - 1);
    function inc(x) = (x == max)? 0: x + 1;
    function dec(x) = (x == 0)? max: x - 1;

    Reg#(taddr) rptr <- mkReg(0);
    Reg#(taddr) wptr <- mkReg(0);
    Reg#(Bool) sramfull <- mkReg(False);
    Reg#(Bool) rdvalid <- mkReg(False);
    let deq_w <- mkPulseWire;
    RWire#(tdata) enq_w <- mkRWire;
    Bool sramempty = (rptr == wptr) && !sramfull;
    
    /*
    Reg#(taddr) howfull <- mkReg(0);
    Reg#(taddr) maxhowfull <- mkReg(0);

    rule update_howfull;
      let howfullval = 0;
      if (wptr >= rptr) howfullval = wptr - rptr;
      else howfullval = (max  + 1) - (rptr - wptr);
      howfull <= howfullval;
      if (howfullval > maxhowfull) maxhowfull <= howfullval;
    endrule
    */

    rule do_stuff;
        let writing = False;
        let reading = False;
        if (enq_w.wget matches tagged Valid .d) begin
            sram.write(wptr, pack(d), '1);
            writing = True;
        end
        if ((deq_w || !rdvalid) && !sramempty) begin
            sram.read(rptr);
            reading = True;
        end

        if (reading) rptr <= inc(rptr);
        if (writing) wptr <= inc(wptr);
        case (tuple2(reading, writing)) matches
            {True, False}: if (rptr == wptr) sramfull <= False;
            {False, True}: if (rptr == inc(wptr)) sramfull <= True;
        endcase

        if (reading) rdvalid <= True;
        else if(deq_w) rdvalid <= False;
    endrule

    method enq(din) = when(!sramfull, enq_w.wset(din));
    method first = when(rdvalid, unpack(sram.rdata));
    method deq = when(rdvalid, deq_w.send);

    method clear = action
        rptr <= 0;
        wptr <= 0;
        sramfull <= False;
        rdvalid <= False;
    endaction;
endmodule

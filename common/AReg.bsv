import GetPut::*;
import Connectable::*;

// Interfaces
interface ARead#(type t);
    method ActionValue#(t) _read;
endinterface

interface Write#(type t);
    method Action _write(t val);
endinterface

interface AReg#(type tread, type twrite);
    method ActionValue#(tread) _read;
    method Action _write(twrite val);
endinterface

typedef AReg#(t, t) AReg1#(type t);

// Add the interfaces to ToPut and ToGet
instance ToPut#(Write#(t), t);
    function toPut(ifc) = interface Put
        method put = ifc._write;
    endinterface;
endinstance

instance ToGet#(ARead#(t), t);
    function toGet(ifc) = interface Get
        method get = ifc._read;
    endinterface;
endinstance

instance ToPut#(AReg#(trd, twr), twr);
    function toPut(ifc) = interface Put
        method put = ifc._write;
    endinterface;
endinstance

instance ToGet#(AReg#(trd, twr), trd);
    function toGet(ifc) = interface Get
        method get = ifc._read;
    endinterface;
endinstance

// Interface transformers
function ARead#(t) toARead(tifc ifc) provisos(ToGet#(tifc, t)) = interface ARead
    method _read = toGet(ifc).get;
endinterface;

function Write#(t) toWrite(tifc ifc) provisos(ToPut#(tifc, t)) = interface Write
    method _write = toPut(ifc).put;
endinterface;

function AReg#(trd, twr) toAReg(tifc ifc)
    provisos(ToGet#(tifc, trd), ToPut#(tifc, twr))
  = interface AReg
        method _read = toGet(ifc).get;
        method _write = toPut(ifc).put;
    endinterface;

function AReg#(trd, twr) toAReg2(tget g, tput p)
    provisos(ToGet#(tget, trd), ToPut#(tput, twr))
  = interface AReg
        method _read = toGet(g).get;
        method _write = toPut(p).put;
    endinterface;

// Module + interface transformer
module mkAReg(module#(tifc) mkIfc, AReg#(trd, twr) ifc)
    provisos(ToGet#(tifc, trd), ToPut#(tifc, twr));
    let _m <- mkIfc;
    return toAReg(_m);
endmodule

// mkConnections
instance Connectable#(ARead#(t), Write#(t));
    module mkConnection#(ARead#(t) a, Write#(t) b)();
        mkConnection(a._read, b._write);
    endmodule
endinstance

instance Connectable#(Write#(t), ARead#(t));
    module mkConnection#(Write#(t) b, ARead#(t) a)();
        mkConnection(b._write, a._read);
    endmodule
endinstance

instance Connectable#(AReg#(tx, ty), AReg#(ty, tx));
    module mkConnection#(AReg#(tx, ty) a, AReg#(ty, tx) b)();
        mkConnection(a._write, b._read);
        mkConnection(a._read, b._write);
    endmodule
endinstance

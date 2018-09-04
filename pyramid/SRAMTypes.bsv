import AReg::*;

typedef Tuple4#(taddr, Bit#(dsz), Bit#(dsz), Bool)
    SRAMWrReq#(type taddr, numeric type dsz);

interface SRAM#(type taddr, numeric type dsz);
    interface AReg#(Bit#(dsz), taddr) rserver;
    interface Write#(SRAMWrReq#(taddr, dsz)) wput;
endinterface

typeclass SRAMWrReqTC#(type taddr, numeric type dsz, type d)
    dependencies (d determines (taddr, dsz));
    function d wreq(taddr addr, Bit#(dsz) data);
endtypeclass

instance SRAMWrReqTC#(taddr, dsz, SRAMWrReq#(taddr, dsz));
    function wreq(addr, data) = tuple4(addr, data, '1, False);
endinstance

instance SRAMWrReqTC#(taddr, dsz, 
                      function SRAMWrReq#(taddr, dsz) f(Bit#(dsz) bwe));
    function wreq(addr, data, bwe) = tuple4(addr, data, bwe, False);
endinstance

instance SRAMWrReqTC#(taddr, dsz, 
                      function SRAMWrReq#(taddr, dsz) f(Bool wt));
    function wreq(addr, data, wt) = tuple4(addr, data, '1, wt);
endinstance

instance SRAMWrReqTC#(taddr, dsz, 
                      function SRAMWrReq#(taddr, dsz) f(Bit#(dsz) bwe, Bool wt));
    function wreq(addr, data, bwe, wt) = tuple4(addr, data, bwe, wt);
endinstance

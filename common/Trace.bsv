import FShow::*;
import List::*;

function Action trace(String tag, d val)
provisos(FShow#(d))
= action
    let notrace <- $test$plusargs("notrace");
    if (!notrace) $display($stime, "\t", tag, "\t", fshow(val));
endaction;

function Action traceIn(List#(String) tags, String tag, d val)
provisos(FShow#(d))
= action
    if (List::elem(tag, tags)) trace(tag, val);
endaction;

function Action epStart(String epoch, d val)
provisos(FShow#(d))
= trace("start " + epoch, val);

function Action epStop(String epoch, d val)
provisos(FShow#(Tuple3#(String, d, String)))
= trace("end " + epoch, val);

instance FShow#(Fmt);
    function fshow = id;
endinstance

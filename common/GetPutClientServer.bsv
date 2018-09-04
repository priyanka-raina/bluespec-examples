import GetPut::*;
import ClientServer::*;

/* Generic put and get functions on interfaces that can be converted to
   Put and Get. If the interface is only being used with put and get,
   consider using AReg instead.
   e.g. let f <- mkFIFO; let val <- get(f); */
function ActionValue#(tdata) get(tifc ifc) provisos(ToGet#(tifc, tdata))
  = toGet(ifc).get;

function Action put(tifc ifc, tdata data) provisos(ToPut#(tifc, tdata))
  = toPut(ifc).put(data);

/*
function Action moveTo(tput iput, tget iget) provisos(ToPut#(tput, tdata), ToGet#(tget, tdata))
  = action
      tdata val <- get(iget);
      put(iput, val);
  endaction;
*/
// Add GetS, Client, and Server to ToGet and ToPut typeclasses
/*
instance ToGet#(GetS#(d), d);
    function toGet(gets) = interface Get
        method ActionValue#(d) get;
            gets.deq;
            return gets.first;
        endmethod
    endinterface;
endinstance

instance ToGet#(Server#(treq, tresp), tresp);
    function toGet(server) = server.response;
endinstance
instance ToPut#(Server#(treq, tresp), treq);
    function toPut(server) = server.request;
endinstance

instance ToGet#(Client#(treq, tresp), treq);
    function toGet(client) = client.request;
endinstance
instance ToPut#(Client#(treq, tresp), tresp);
    function toPut(client) = client.response;
endinstance

*/

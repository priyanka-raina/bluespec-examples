import List::*;

typeclass BuildList#(type a, type r)
   dependencies (r determines a);
   function r buildList_(List#(a) v, a x);
endtypeclass

instance BuildList#(a, List#(a));
    function buildList_(v, x) = List::reverse(List::cons(x, v));
endinstance

instance BuildList#(a, function r f(a y))
    provisos(BuildList#(a, r));

    function buildList_(v, x) = buildList_(List::cons(x, v));
endinstance

function r list(a x) provisos(BuildList#(a, r)) = buildList_(List::nil, x);

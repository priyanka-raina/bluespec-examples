typedef ActionValue#(tx) AV#(type tx);

// Combine Action and Value into ActionValue
function AV#(d) toAV(Action a, d x) = actionvalue
    a;
    return x;
endactionvalue;

function AV#(d) noAV(d x) = toAV(noAction, x);

function AV#(tf) liftAV(function tf f(ta a), AV#(ta) ava)
  = actionvalue
      let va <- ava;
      return f(va);
    endactionvalue;

function AV#(tf) lift2AV(function tf f(ta a, tb b), AV#(ta) ava, AV#(tb) avb)
  = actionvalue
      let va <- ava;
      let vb <- avb;
      return f(va, vb);
    endactionvalue;

// Arithmetic operations on ActionValues
instance Literal#(AV#(t)) provisos(Literal#(t));
    function fromInteger(i) = actionvalue
        return fromInteger(i);
    endactionvalue;

    function inLiteralRange(x, i) = begin
        t a = ?;
        inLiteralRange(a, i);
    end;
endinstance

instance Arith#(AV#(t)) provisos(Arith#(t));
    function \+     = lift2AV(\+ );
    function \-     = lift2AV(\- );
    function negate = liftAV(negate);
    function \*     = lift2AV(\* );
    function \/     = lift2AV(\/ );
    function \%     = lift2AV(\% );
    function abs    = liftAV(abs);
    function signum = liftAV(signum);
    function \**    = lift2AV(\** );
    function log2   = liftAV(log2);
    function exp_e  = liftAV(exp_e);
    function log    = liftAV(log);
    function logb   = lift2AV(logb);
    function log10  = liftAV(log10);
endinstance

/* Common functions combining arithmetic operations and type conversion
   such as proper addition, convert unsigned to/from signed. */

// UInt#(n) <=> Int#(n)
function dout bitConv(din xin) provisos (Bits#(din, sz), Bits#(dout, sz)) = unpack(pack(xin));

// UInt#(n) -> UInt#(n+d), Int#(n) -> Int#(n+d), UInt#(n) -> Int#(n+d)
function dout convert(din#(m) xin) provisos (Bits#(dout, szout), Bits#(din#(szout), szout), BitExtend#(m, szout, din)) = begin
    din#(szout) v = extend(xin);
    unpack(pack(v));
end;

// UInt#(n) + UInt#(n) -> UInt#(n+1), Int#(n) + Int#(n) -> Int#(n+1)
function d#(m) add(d#(n) a, d#(n) b) provisos (Add#(n, 1, m), BitExtend#(n, m, d), Arith#(d#(m)))
  = extend(a) + extend(b);

// UInt#(n) -> Int#(n+1)
function Int#(TAdd#(n, 1)) toInt(UInt#(n) a)
  = bitConv(extend(a));

// Int#(n) -> UInt#(n)
function UInt#(n) uAbs(Int#(n) a)
  = bitConv(abs(a)); // handles the corner case where abs(-2^n) returns -2^n

function d clip(d in, d minv, d maxv) provisos (Ord#(d))
  = min(maxv, max(minv, in));

function Tuple2#(d, d) min_max(d a, d b) provisos (Ord#(d)) = begin
    let ord = compare(a, b);
    let minv = ord == LT? a: b;
    let maxv = ord == GT? a: b;
    tuple2(minv, maxv);
end;

function Action incr(Reg#(d) r, d x) provisos (Arith#(d))
  = action r <= r + x; endaction;

function Action set(Reg#(a) x, a x1) = writeReg(x, x1);

function d mux(Bool pred, d if_val, d else_val) = pred? if_val: else_val;

// Maybe#(d) -> d with guard
function d whenValid(Maybe#(d) x) = when(isValid(x), fromMaybe(?, x));

// Bool, d -> Maybe#(d)
function Maybe#(d) toMaybe(Bool isValid, d x) = isValid? tagged Valid x: Invalid;

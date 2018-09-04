import Vector::*;

/* Build a vector. e.g. Vector#(4, int) v = vector(3, 4, 1, 12);
   Taken from http://www.bluespec.com/forum/viewtopic.php?p=1317
*/
typeclass BuildVector#(type a, type r, numeric type n)
   dependencies (r determines (a, n));
   function r buildVec_(Vector#(n, a) v, a x);
endtypeclass

instance BuildVector#(a, Vector#(m, a), n) provisos(Add#(n, 1, m));
    function buildVec_(v, x) = reverse(cons(x, v));
endinstance

instance BuildVector#(a, function r f(a y), n)
    provisos(BuildVector#(a, r, m), Add#(n, 1, m));

    function buildVec_(v, x) = buildVec_(cons(x, v));
endinstance

function r vector(a x) provisos(BuildVector#(a, r, 0)) = buildVec_(nil, x);

// Arithmetic operations on vectors
instance Literal#(Vector#(n, dtype)) provisos (Literal#(dtype));
    function fromInteger(i) = replicate(fromInteger(i));

    function inLiteralRange(x, i) = begin
        dtype a = ?;
        inLiteralRange(a, i);
    end;
endinstance

instance Arith#(Vector#(n, dtype)) provisos (Arith#(dtype));
    function \+     = zipWith(\+ );
    function \-     = zipWith(\- );
    function negate = map(negate);
    function \*     = zipWith(\* );
    function \/     = zipWith(\/ );
    function \%     = zipWith(\% );
    function abs    = map(abs);
    function signum = map(signum);
    function \**    = zipWith(\** );
    function log2   = map(log2);
    function exp_e  = map(exp_e);
    function log    = map(log);
    function logb   = zipWith(logb);
    function log10  = map(log10);
endinstance

function Vector#(n1, d) vecExtendWith(d din, Vector#(n2, d) vin)
provisos (Add#(n2, a, n1))
= begin
    Vector#(a, d) appendVec = replicate(din);
    append(vin, appendVec);
end;

function Vector#(n1, d) vecExtend(Vector#(n2, d) vin)
provisos (Add#(n2, a, n1))
= begin
    Vector#(a, d) appendVec = newVector;
    append(vin, appendVec);
end;

typedef Vector#(n1, Vector#(n2, d))
    Vector2D#(numeric type n1, numeric type n2, type d);

typedef Vector#(n1, Vector#(n2, Vector#(n3, d)))
    Vector3D#(numeric type n1, numeric type n2, numeric type n3, type d);

function Vector2D#(n1, n2, dq) arrayToVector2D(dq arr[][])
= map(arrayToVector, arrayToVector(arr));

function Vector2D#(n1, n2, dq) map2d(function dq f(di x), Vector2D#(n1, n2, di) vin)
= map(map(f), vin);

function Vector2D#(n1, n2, di) replicate2d(di x)
= replicate(replicate(x));

function Vector3D#(n1, n2, n3, dq) map3d(function dq f(di x), Vector3D#(n1, n2, n3, di) vin)
= map(map(map(f)), vin);

function Vector3D#(n1, n2, n3, di) replicate3d(di x)
= replicate(replicate(replicate(x)));

function Vector2D#(n1, n2, d) decat(Vector#(n, d) vin)
provisos (Mul#(n1, n2, n), Add#(n2, a__, n))
= begin
    function Vector#(n2, d) f(Integer idx)
    = takeAt(idx*valueOf(n2), vin);
    genWith(f);
end;

function Vector2D#(n1, n2, d) reshape(Vector2D#(n3, n4, d) vec2)
provisos (Mul#(n1, n2, n), Mul#(n3, n4, n), Add#(n2, a__, n))
= begin
    Vector#(n, d) v = concat(vec2);
    decat(v);
end;

function dout min_argmin(Vector#(n, d) vin) provisos(Ord#(d), Add#(1, _, n), Alias#(dout, Tuple2#(d, UInt#(TLog#(n)))));
    function dout f(Integer ix) = tuple2(vin[ix], fromInteger(ix));
    Vector#(n, dout) vec = genWith(f);

    function dout redf(dout v1, dout v2) = tpl_1(v1) > tpl_1(v2)? v2: v1;
    return fold(redf, vec);
endfunction

function dout max_argmax(Vector#(n, d) vin) provisos(Ord#(d), Add#(1, _, n), Alias#(dout, Tuple2#(d, UInt#(TLog#(n)))));
    function dout f(Integer ix) = tuple2(vin[ix], fromInteger(ix));
    Vector#(n, dout) vec = genWith(f);

    function dout redf(dout v1, dout v2) = tpl_1(v1) > tpl_1(v2)? v1: v2;
    return fold(redf, vec);
endfunction

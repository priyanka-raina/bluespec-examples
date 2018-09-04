import Vector::*;

import VectorOps::*;

function Bit#(dbits) pyr_apply_filter (Vector#(5, Bit#(dbits)) din);
  UInt#(TAdd#(dbits, 4)) inter;
  inter = (extend(unpack(din[0])) + extend(unpack(din[4]))) + 
          (extend(unpack(din[1])) + extend(unpack(din[3]))) * 4 + 
           extend(unpack(din[2])) * 6;
  UInt#(dbits) dout = truncate(inter >> 4);
  return pack(dout);
endfunction


function Vector#(TAdd#(TMul#(2, 2), 1), Bit#(dbits)) pyr_rearrange (Vector#(TMul#(2, 2), Bit#(dbits)) ds, 
  Bit#(dbits) din, UInt#(TLog#(TMul#(2, 2))) rotateby, Bit#(TLog#(TAdd#(TMul#(2, 2), 1))) coltype);
  let inter = case(coltype)
    0: vector(din,   ds[1], ds[0], ds[1], din); // 0
    1: vector(ds[1], ds[0], ds[1], ds[2], din); // 1
    default: vecExtendWith(din, reverse(rotateBy(reverse(ds), rotateby)));
  endcase;
  return case(coltype)
    3: vector(inter[0], inter[1], inter[2], inter[3], inter[2]); // cols - 2
    2: vector(inter[0], inter[1], inter[2], inter[1], inter[0]); // cols - 1
    default: inter;
  endcase;
endfunction


function Vector#(5, d) perm (Vector#(5, d) v, Bit#(hbits) r, Bit#(wbits) c, Bit#(hbits) rc, Bit#(wbits) cc);
      let vv = v;
      case (cc)
        0:  case (rc)
              0: vv = vector(v[2], v[1], v[0], v[1], v[2]);
              1: vv = vector(v[1], v[0], v[1], v[2], v[3]);
            endcase
        default: case (rc)
              0: vv = vector(v[4], v[3], v[2], v[3], v[4]);   
              1: vv = vector(v[2], v[1], v[2], v[3], v[4]);
            endcase
      endcase
      
      case (cc)
        (c - 1): case (rc)
          (r - 2): vv = vector(v[1], v[2], v[3], v[4], v[3]);
          (r - 1): vv = vector(v[2], v[3], v[4], v[3], v[2]);
        endcase
        default: case (rc)
          (r - 2): vv = vector(v[0], v[1], v[2], v[3], v[2]);
          (r - 1): vv = vector(v[0], v[1], v[2], v[1], v[0]);
        endcase
      endcase
    return vv;
  endfunction


function Bit#(hbits) incr_row (Bit#(hbits) row, Bit#(hbits) num_rows) = 
  (row == num_rows - 1) ? 0 : row + 1;


function Bit#(wbits) incr_col (Bit#(wbits) col, Bit#(wbits) num_cols, Bit#(hbits) row, Bit#(hbits) num_rows) = 
  (row == num_rows - 1) ? ((col == num_cols - 1) ? 0 : col + 1) : col;  


function Integer get_num_levels (Integer rows, Integer cols);
  Integer h = rows;
  Integer w = cols;
  Integer levels = 0;
  while ((h > 20) && (w > 20)) begin
    levels = levels + 1;
    h = (h + 1)/2;
    w = (w + 1)/2;
  end 
  return levels;
endfunction


function Tuple2#(Integer, Integer) get_level_size (Integer rows, Integer cols, Integer level);
  Integer h = rows;
  Integer w = cols;
  Integer l = 0;
  while (l < level) begin
    h = (h + 1)/2;
    w = (w + 1)/2;
    l = l + 1;
  end
  return tuple2(h, w);
endfunction


function Integer get_level_pixels (Integer rows, Integer cols, Integer level);
  let level_size = get_level_size(rows, cols, level);
  return tpl_1(level_size)*tpl_2(level_size);
endfunction

String sram_prefix = "TS6N40LPA";

function String downsampling_buffer_name (Integer height);
  return sram_prefix + 
  case (height)
    720: "EXT720X12M4S";
    360: "368X16M4S";
    180: "192X16M4S";
     90: "96X16M2S";
     45: "48X16M2F";
     23: "24X16M2F";
  endcase;
endfunction

function String upsampling_buffer_name (Integer height);
  return sram_prefix + 
  case (height)
    720: "720X16M4S";
    360: "368X16M4S";
    180: "192X16M4S";
     90: "96X16M2S";
     45: "48X16M2F";
     23: "24X16M2F";
  endcase;
endfunction

function String luminance_buffer_name (Integer height);
  return sram_prefix + 
  case (height)
    720: "2880X16M8S";
    360: "1440X16M4S";
    180: "720X16M4S";
     90: "368X16M4S";
     45: "192X16M4S";
     23: "96X16M2S";
  endcase;
endfunction

function String laplacian_buffer_name (Integer height);
  return sram_prefix + 
  case (height)
    720: "720X17M4S";
    360: "368X17M4S";
    180: "192X17M4S";
     90: "96X17M2S";
     45: "48X17M2F";
     23: "24X17M2F";
  endcase;
endfunction

function String lowpass_buffer_name ();
  return sram_prefix + "240X16M4S";
endfunction

function String spatial_buffer_name (Integer height);
  return sram_prefix + 
  case (height)
    720: "720X16M4S";
    360: "368X16M4S";
    180: "192X16M4S";
     90: "96X16M2S";
     45: "48X16M2F";
     23: "24X16M2F";
  endcase;
endfunction

function String cos_sin_buffer_name (Integer height);
  return sram_prefix + 
  case (height)
    720: "2880X51M8S";
    360: "1440X51M4S";
    180: "720X51M2S";
     90: "368X51M2S";
     45: "192X51M2S";
     23: "96X51M2S";
  endcase;
endfunction

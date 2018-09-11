# Riesz Pyramid Constructor

## Run
* To compile
```
./compile.sh
```
* To run
```
./run.sh
```

## Description
Takes an image as input and generates its riesz pyramid (this is similar to a laplacian pyramid with some extra components).

[`PyramidConstructor.bsv`](PyramidConstructor.bsv) has the following modules:
* `mkPyramidConstructor` - This is a generator for the riesz pyramid constructor. It takes three parameters:
  * `dbits` - Bit width of the image pixels
  * `maxheight` - Maximum height of the image
  * `maxwidth` - Maximum width of the image

* `mkPyramidConstructorInst` - Is the instantiation of the above generator with the following parameters:
  * `dbits` = 16
  * `maxheight` = 720
  * `maxwidth` = 1280
  
  This is the only logic that will be in the application, and therefore is the design under test.
  Bluespec does not generate verilog for generators, it generates verilog for specific instantiations of the generator. 
  
* `mkTbPyramidConstructor` - Is a testbench for `mkPyramidConstructorInst`. It is not fabricated, it is used only for simulation (unit testing).
  
### I/O interface of mkPyramidConstructor
```
interface PyramidConstructor#(numeric type dbits, numeric type maxheight, numeric type maxwidth);
  interface Put#(Bit#(dbits)) put_pixel;
  interface Get#(Bit#(dbits)) get_lowpass_pixel;
  interface Get#(Tuple2#(Vector#(3, Int#(TAdd#(dbits, 1))), Bit#(TLog#(TSub#(TLog#(maxheight), 5))))) get_riesz;
  method Action set_image_size (Bit#(TLog#(maxheight)) height, Bit#(TLog#(maxwidth)) width);
endinterface
```
* The input image pixels are written in serially using `put_pixel`. Each pixel has `dbits` bits.
* The lowest resolution (low pass) image pixels are read out serially using `get_lowpass_pixel`. Each low pass pixel has `dbits` bits.
* The riesz pyramid pixels are read out serially using `get_riesz`. It returns a tuple of two values - the first value is the riesz pixel and the second value is a tag representing which pyramid level the pixel belongs to. Riesz pixel is a vectors of 3 values each with `dbits + 1` bits. The 3 values are the laplacian, the horizontal derivative of the laplacian and the vertical derivative of the laplacian.
* `set_image_size` is used the set the image height and wight. This must be called before above methods are called. See the testbench in [`PyramidConstructor.bsv`](PyramidConstructor.bsv) for details.

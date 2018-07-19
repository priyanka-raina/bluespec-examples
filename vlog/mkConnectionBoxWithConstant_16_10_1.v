//
// Generated by Bluespec Compiler, version 2016.07.beta1 (build 34806, 2016-07-05)
//
// On Thu Jul 19 12:49:49 EDT 2018
//
//
// Ports:
// Name                         I/O  size props
// mux                            O    16
// RDY_mux                        O     1 const
// RDY_write_select               O     1 const
// read_select                    O     4 reg
// RDY_read_select                O     1 const
// CLK                            I     1 clock
// RST_N                          I     1 reset
// mux_in                         I   160
// write_select_select            I     4 reg
// EN_write_select                I     1
//
// Combinational paths from inputs to outputs:
//   mux_in -> mux
//
//

`ifdef BSV_ASSIGNMENT_DELAY
`else
  `define BSV_ASSIGNMENT_DELAY
`endif

`ifdef BSV_POSITIVE_RESET
  `define BSV_RESET_VALUE 1'b1
  `define BSV_RESET_EDGE posedge
`else
  `define BSV_RESET_VALUE 1'b0
  `define BSV_RESET_EDGE negedge
`endif

module mkConnectionBoxWithConstant_16_10_1(CLK,
					   RST_N,

					   mux_in,
					   mux,
					   RDY_mux,

					   write_select_select,
					   EN_write_select,
					   RDY_write_select,

					   read_select,
					   RDY_read_select);
  input  CLK;
  input  RST_N;

  // value method mux
  input  [159 : 0] mux_in;
  output [15 : 0] mux;
  output RDY_mux;

  // action method write_select
  input  [3 : 0] write_select_select;
  input  EN_write_select;
  output RDY_write_select;

  // value method read_select
  output [3 : 0] read_select;
  output RDY_read_select;

  // signals for module outputs
  reg [15 : 0] mux;
  wire [3 : 0] read_select;
  wire RDY_mux, RDY_read_select, RDY_write_select;

  // register dut_constant_r
  reg [15 : 0] dut_constant_r;
  wire [15 : 0] dut_constant_r$D_IN;
  wire dut_constant_r$EN;

  // register dut_select_r
  reg [3 : 0] dut_select_r;
  wire [3 : 0] dut_select_r$D_IN;
  wire dut_select_r$EN;

  // rule scheduling signals
  wire CAN_FIRE_write_select, WILL_FIRE_write_select;

  // value method mux
  always@(dut_select_r or dut_constant_r or mux_in)
  begin
    case (dut_select_r)
      4'd0: mux = dut_constant_r;
      4'd1: mux = mux_in[15:0];
      4'd2: mux = mux_in[31:16];
      4'd3: mux = mux_in[47:32];
      4'd4: mux = mux_in[63:48];
      4'd5: mux = mux_in[79:64];
      4'd6: mux = mux_in[95:80];
      4'd7: mux = mux_in[111:96];
      4'd8: mux = mux_in[127:112];
      4'd9: mux = mux_in[143:128];
      4'd10: mux = mux_in[159:144];
      default: mux = 16'b1010101010101010 /* unspecified value */ ;
    endcase
  end
  assign RDY_mux = 1'd1 ;

  // action method write_select
  assign RDY_write_select = 1'd1 ;
  assign CAN_FIRE_write_select = 1'd1 ;
  assign WILL_FIRE_write_select = EN_write_select ;

  // value method read_select
  assign read_select = dut_select_r ;
  assign RDY_read_select = 1'd1 ;

  // register dut_constant_r
  assign dut_constant_r$D_IN = 16'h0 ;
  assign dut_constant_r$EN = 1'b0 ;

  // register dut_select_r
  assign dut_select_r$D_IN = write_select_select ;
  assign dut_select_r$EN = EN_write_select ;

  // handling of inlined registers

  always@(posedge CLK)
  begin
    if (RST_N == `BSV_RESET_VALUE)
      begin
        dut_constant_r <= `BSV_ASSIGNMENT_DELAY 16'd23;
	dut_select_r <= `BSV_ASSIGNMENT_DELAY 4'd0;
      end
    else
      begin
        if (dut_constant_r$EN)
	  dut_constant_r <= `BSV_ASSIGNMENT_DELAY dut_constant_r$D_IN;
	if (dut_select_r$EN)
	  dut_select_r <= `BSV_ASSIGNMENT_DELAY dut_select_r$D_IN;
      end
  end

  // synopsys translate_off
  `ifdef BSV_NO_INITIAL_BLOCKS
  `else // not BSV_NO_INITIAL_BLOCKS
  initial
  begin
    dut_constant_r = 16'hAAAA;
    dut_select_r = 4'hA;
  end
  `endif // BSV_NO_INITIAL_BLOCKS
  // synopsys translate_on
endmodule  // mkConnectionBoxWithConstant_16_10_1


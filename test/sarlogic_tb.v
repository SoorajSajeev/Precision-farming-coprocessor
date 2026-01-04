

module sarlogic_tb;

  /* Make a reset that pulses once. */
  reg reset = 0;
  reg d = 0;
  initial begin
     $dumpfile("sarlogic_tb.vcd");
     $dumpvars(0,sarlogic_tb);

     # 17 reset = 1;
     # 11 reset = 0;
     # 29 reset = 1;
     # 29 d = 1;
     # 100 d = 0;
     # 250 d = 1;
     # 220 d = 1;
     # 5  reset =0;
     # 513 $finish;
  end

  /* Make a regular pulsing clock. */
  reg clk = 0;
  always #1 clk = !clk;

  wire [3:0] bitout;
  wire conv_done;

  sarlogic sar (clk, reset, d, bitout, conv_done);

  initial
     $monitor("At time %t, d=%b, bitout = %h (%0d), conv_done=%b",
              $time, d, bitout, bitout, conv_done);
endmodule // sarlogic_tb

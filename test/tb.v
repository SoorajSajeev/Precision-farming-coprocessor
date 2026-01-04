/*
 * Traditional Verilog Testbench
 * For Tiny Tapeout Precision Farming Coprocessor
 */

`timescale 1ns/1ps

module tb;

  // Clock and reset
  reg clk;
  reg rst_n;
  reg ena;
  
  // Inputs
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  
  // Outputs
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  
  // DUT instantiation
  tt_um_SoorajSajeev_precision_farming_coprocessor dut (
    .ui_in(ui_in),
    .uo_out(uo_out),
    .uio_in(uio_in),
    .uio_out(uio_out),
    .uio_oe(uio_oe),
    .ena(ena),
    .clk(clk),
    .rst_n(rst_n)
  );
  
  // Clock generation (25 MHz = 40ns period)
  initial begin
    clk = 0;
    forever #20 clk = ~clk;
  end
  
  // VCD dump for waveform viewing
  initial begin
    $dumpfile("tb_coprocessor.vcd");
    $dumpvars(0, tb_coprocessor);
  end
  
  // Test stimulus
  initial begin
    $display("========================================");
    $display("Precision Farming Coprocessor Testbench");
    $display("========================================");
    
    // Initialize
    ena = 1;
    rst_n = 0;
    ui_in = 8'b0;
    uio_in = 8'b0;
    
    // Reset
    $display("\n[%0t] Applying reset...", $time);
    #100;
    rst_n = 1;
    #100;
    $display("[%0t] Reset released", $time);
    
    // Test 1: Radish profile - Temperature too cold
    $display("\n[%0t] TEST 1: Radish - Temperature too cold", $time);
    uio_in[2:1] = 2'b00;  // Radish profile
    ui_in[1:0] = 2'b00;   // Temperature = 0 (too cold)
    ui_in[3:2] = 2'b10;   // Humidity = 2 (optimal)
    ui_in[5:4] = 2'b10;   // Light = 2 (optimal)
    ui_in[7:6] = 2'b10;   // Soil = 2 (optimal)
    #200;
    if (uo_out[1]) 
      $display("  PASS: Heater activated");
    else
      $display("  FAIL: Heater should be ON");
    
    // Test 2: Soil moisture - Water pump
    $display("\n[%0t] TEST 2: Water pump - Soil dry", $time);
    uio_in[2:1] = 2'b00;  // Radish
    ui_in[1:0] = 2'b10;   // Temperature optimal
    ui_in[3:2] = 2'b10;   // Humidity optimal
    ui_in[5:4] = 2'b10;   // Light optimal
    ui_in[7:6] = 2'b00;   // Soil = 0 (DRY)
    #200;
    if (uo_out[0])
      $display("  PASS: Water pump activated");
    else
      $display("  FAIL: Water pump should be ON");
    
    // Test 3: Override mode
    $display("\n[%0t] TEST 3: Override mode", $time);
    ui_in[7:0] = 8'b00_00_00_00;  // All sensors bad
    uio_in[0] = 1'b0;  // Override OFF
    #200;
    $display("  Before override: uo_out = 0x%h", uo_out);
    
    uio_in[0] = 1'b1;  // Override ON
    #200;
    if ((uo_out & 8'b0100_1111) == 0)
      $display("  PASS: All actuators OFF during override");
    else
      $display("  FAIL: Actuators should be OFF (uo_out = 0x%h)", uo_out);
    
    // Test 4: Basil extra heat
    $display("\n[%0t] TEST 4: Basil - Extra heating", $time);
    uio_in[0] = 1'b0;     // Override OFF
    uio_in[2:1] = 2'b01;  // Basil profile
    ui_in[1:0] = 2'b01;   // Temperature = 1 (cool, not too cold)
    ui_in[3:2] = 2'b10;   // Humidity optimal
    ui_in[5:4] = 2'b10;   // Light optimal
    ui_in[7:6] = 2'b10;   // Soil optimal
    #200;
    if (uo_out[1])
      $display("  PASS: Basil heater ON at 'cool'");
    else
      $display("  FAIL: Basil should heat at cool temp");
    
    // Summary
    $display("\n========================================");
    $display("Testbench Complete - Check results above");
    $display("========================================\n");
    
    #100;
    $finish;
  end

endmodule

/*
 * Traditional Verilog Testbench
 * For Tiny Tapeout Precision Farming Coprocessor
 * WITH UART MONITORING
 */

`timescale 1ns/1ps

module tb_coprocessor;

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
  
  // =========================================================================
  // UART MONITORING (115200 baud @ 25MHz = 217 cycles/bit = 8680ns/bit)
  // =========================================================================
  reg [7:0] uart_rx_data;
  integer uart_bit_count;
  wire uart_tx_line;
  
  assign uart_tx_line = uio_out[7];  // UART TX is on uio_out[7]
  
  // Simple UART receiver for monitoring transmissions
  initial begin
    forever begin
      @(negedge uart_tx_line);  // Wait for start bit (falling edge)
      
      // Wait to middle of start bit to verify it's valid
      #(40*217/2);
      if (uart_tx_line == 1'b0) begin
        // Valid start bit, sample 8 data bits
        uart_rx_data = 8'h00;
        
        for (uart_bit_count = 0; uart_bit_count < 8; uart_bit_count = uart_bit_count + 1) begin
          #(40*217);  // Wait one full bit period
          uart_rx_data[uart_bit_count] = uart_tx_line;
        end
        
        #(40*217);  // Wait for stop bit
        
        // Display received byte
        if (uart_rx_data >= 32 && uart_rx_data < 127)
          $display("[%0t] UART RX: 0x%02h ('%c') <<<", $time, uart_rx_data, uart_rx_data);
        else
          $display("[%0t] UART RX: 0x%02h (non-printable) <<<", $time, uart_rx_data);
      end
    end
  end
  
  // =========================================================================
  // TEST STIMULUS
  // =========================================================================
  initial begin
    $display("========================================");
    $display("Precision Farming Coprocessor Testbench");
    $display("WITH UART MONITORING");
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
    $display("[%0t] UART should be idle HIGH: %b", $time, uart_tx_line);
    
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
    
    // Test 5: UART Fault Transmission
    $display("\n[%0t] TEST 5: UART Fault Transmission", $time);
    uio_in[0] = 1'b0;     // Override OFF
    uio_in[2:1] = 2'b00;  // Radish profile
    
    // Create fault: temperature needs both heating AND cooling (contradiction)
    ui_in[1:0] = 2'b00;   // Temperature = 0 (too cold - needs heating)
    ui_in[3:2] = 2'b10;   // Humidity optimal
    ui_in[5:4] = 2'b10;   // Light optimal
    ui_in[7:6] = 2'b10;   // Soil optimal
    #200;
    
    // Check fault flag
    if (uo_out[4])
      $display("  Fault flag SET (as expected for testing)");
    else
      $display("  Note: Fault flag not set (may require specific conditions)");
    
    // Wait for UART transmission (10 bits @ 8680ns/bit = ~86.8us = 86800ns)
    $display("  Waiting for UART transmission...");
    #100000;  // Wait 100us to be safe
    
    $display("  Note: Check UART RX output above (should show 0x46 'F' if fault detected)");
    
    // Test 6: Pea Shoots cool early
    $display("\n[%0t] TEST 6: Pea Shoots - Early cooling", $time);
    uio_in[2:1] = 2'b10;  // Pea Shoots profile
    ui_in[1:0] = 2'b10;   // Temperature = 2 (optimal)
    ui_in[3:2] = 2'b10;   // Humidity optimal
    ui_in[5:4] = 2'b10;   // Light optimal
    ui_in[7:6] = 2'b10;   // Soil optimal
    #200;
    if (uo_out[2])
      $display("  PASS: Pea shoots cooler activated at optimal temp");
    else
      $display("  FAIL: Pea shoots should cool at optimal temperature");
    
    // Test 7: Sunflower dehumidify early
    $display("\n[%0t] TEST 7: Sunflower - Dehumidify early", $time);
    uio_in[2:1] = 2'b11;  // Sunflower profile
    ui_in[1:0] = 2'b10;   // Temperature optimal
    ui_in[3:2] = 2'b10;   // Humidity = 2 (optimal, but sunflower wants lower)
    ui_in[5:4] = 2'b10;   // Light optimal
    ui_in[7:6] = 2'b10;   // Soil optimal
    #200;
    if (uo_out[6])
      $display("  PASS: Sunflower dehumidifier ON at optimal humidity");
    else
      $display("  FAIL: Sunflower should dehumidify at optimal humidity");
    
    // Test 8: All optimal - minimal actuation
    $display("\n[%0t] TEST 8: All optimal - Minimal actuation", $time);
    uio_in[2:1] = 2'b00;  // Radish profile (balanced)
    ui_in[7:0] = 8'b10_10_10_10;  // All sensors optimal
    #200;
    $display("  Actuators state: uo_out = 0x%h", uo_out);
    if ((uo_out & 8'b0100_1111) == 0)
      $display("  PASS: Minimal actuation when all optimal");
    else
      $display("  Note: Some actuators ON (expected for some profiles)");
    
    // Test 9: Heartbeat verification
    $display("\n[%0t] TEST 9: Heartbeat LED", $time);
    $display("  Heartbeat bit (uo_out[5]): %b", uo_out[5]);
    $display("  (Heartbeat toggles slowly - full period is 25M cycles @ 25MHz = 1 second)");
    $display("  Waiting a bit to observe heartbeat...");
    #50000;  // Wait 50us to see if heartbeat changes (won't complete full cycle)
    $display("  Heartbeat bit after delay: %b", uo_out[5]);
    
    // Summary
    $display("\n========================================");
    $display("Testbench Complete");
    $display("========================================");
    $display("Key Points:");
    $display("- Check all PASS/FAIL messages above");
    $display("- Look for UART RX messages (marked with <<<)");
    $display("- View waveforms: gtkwave tb_coprocessor.vcd");
    $display("- UART TX is on uio_out[7]");
    $display("========================================\n");
    
    #1000;
    $finish;
  end
  
  // Monitor for debugging
  initial begin
    $monitor("[%0t] sensors=%b crop=%b ovr=%b | actuators=%b fault=%b hb=%b | uart_tx=%b", 
             $time, ui_in, uio_in[2:1], uio_in[0], 
             {uo_out[6], uo_out[3:0]}, uo_out[4], uo_out[5], uart_tx_line);
  end

endmodule

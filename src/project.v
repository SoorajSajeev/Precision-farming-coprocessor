/*
 * Copyright (c) 2024 SoorajSajeev
 * SPDX-License-Identifier: Apache-2.0
 * 
 * Precision Farming Coprocessor
 * Autonomous environmental control for microgreens and precision agriculture
 */

`default_nettype none

// =============================================================================
// TOP-LEVEL MODULE (Tiny Tapeout Wrapper)
// =============================================================================

module tt_um_SoorajSajeev_precision_farming_coprocessor (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // Enable - always 1 when the design is powered
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset (active low)
);

  // ===========================================================================
  // Pin Assignments & Signal Naming
  // ===========================================================================
  
  // INPUT SENSORS (ui_in[7:0]) - All 2-bit for 4-level precision
  wire [1:0] sensor_temperature;   // 0=too_cold, 1=cool, 2=optimal, 3=too_hot
  wire [1:0] sensor_humidity;      // 0=too_dry, 1=low, 2=optimal, 3=too_humid
  wire [1:0] sensor_light;         // 0=dark, 1=low, 2=optimal, 3=too_bright
  wire [1:0] sensor_soil_moisture; // 0=dry, 1=slightly_dry, 2=optimal, 3=saturated
  
  assign sensor_temperature   = ui_in[1:0];
  assign sensor_humidity      = ui_in[3:2];
  assign sensor_light         = ui_in[5:4];
  assign sensor_soil_moisture = ui_in[7:6];
  
  // BIDIRECTIONAL CONTROL INPUTS (uio_in[7:0])
  wire       cmd_override;   // Main processor override command
  wire [1:0] crop_select;    // Crop profile selector
  wire       uart_rx;        // UART receive (future)
  
  assign cmd_override = uio_in[0];
  assign crop_select  = uio_in[2:1];
  assign uart_rx      = uio_in[3];
  
  // ACTUATOR OUTPUTS (uo_out[7:0])
  wire ctrl_water_pump;
  wire ctrl_heater;
  wire ctrl_cooler;
  wire ctrl_light;
  wire flag_fault;
  wire status_heartbeat;
  wire ctrl_dehumidifier;
  
  assign uo_out[0] = ctrl_water_pump;
  assign uo_out[1] = ctrl_heater;
  assign uo_out[2] = ctrl_cooler;
  assign uo_out[3] = ctrl_light;
  assign uo_out[4] = flag_fault;
  assign uo_out[5] = status_heartbeat;
  assign uo_out[6] = ctrl_dehumidifier;
  assign uo_out[7] = 1'b0;  // Reserved
  
  // BIDIRECTIONAL OUTPUTS (uio_out[7:0])
  wire uart_tx;
  
  assign uio_out[7]   = uart_tx;
  assign uio_out[6:0] = 7'b0;
  
  // Bidirectional enable: only bit 7 is output (UART TX)
  assign uio_oe = 8'b1000_0000;

  // ===========================================================================
  // Core Control Logic Instantiation
  // ===========================================================================
  
  ag_control_core core_inst (
    .clk                 (clk),
    .rst_n               (rst_n),
    .ena                 (ena),
    
    // Sensor inputs
    .sensor_temperature  (sensor_temperature),
    .sensor_humidity     (sensor_humidity),
    .sensor_light        (sensor_light),
    .sensor_soil_moisture(sensor_soil_moisture),
    
    // Control inputs
    .cmd_override        (cmd_override),
    .crop_select         (crop_select),
    
    // Actuator outputs
    .ctrl_water_pump     (ctrl_water_pump),
    .ctrl_heater         (ctrl_heater),
    .ctrl_cooler         (ctrl_cooler),
    .ctrl_light          (ctrl_light),
    .ctrl_dehumidifier   (ctrl_dehumidifier),
    
    // Status outputs
    .flag_fault          (flag_fault),
    .status_heartbeat    (status_heartbeat),
    .uart_tx             (uart_tx)
  );

  // Suppress unused signal warnings
  wire _unused = &{uart_rx, 1'b0};

endmodule

// =============================================================================
// CORE CONTROL MODULE
// =============================================================================

module ag_control_core (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,
    
    // Sensor inputs (all 2-bit)
    input  wire [1:0] sensor_temperature,
    input  wire [1:0] sensor_humidity,
    input  wire [1:0] sensor_light,
    input  wire [1:0] sensor_soil_moisture,
    
    // Control inputs
    input  wire       cmd_override,    // Override/pause command
    input  wire [1:0] crop_select,     // Crop profile selector
    
    // Actuator outputs
    output reg        ctrl_water_pump,
    output reg        ctrl_heater,
    output reg        ctrl_cooler,
    output reg        ctrl_light,
    output reg        ctrl_dehumidifier,
    
    // Status outputs
    output reg        flag_fault,
    output reg        status_heartbeat,
    output wire       uart_tx
);

  // ===========================================================================
  // TIMING PARAMETERS
  // ===========================================================================
  
  localparam HEARTBEAT_DIV = 25_000_000;  // 1 Hz at 25 MHz
  localparam FAULT_PERSIST = 100_000;     // ~4ms debounce

  // ===========================================================================
  // CROP PROFILE THRESHOLDS
  // ===========================================================================
  
  // Threshold storage (selected by crop_select)
  reg [1:0] temp_low_threshold;
  reg [1:0] temp_high_threshold;
  reg [1:0] humid_high_threshold;
  reg [1:0] light_low_threshold;
  reg [1:0] soil_low_threshold;
  
  // Additional thresholds for advanced profiles
  reg temp_needs_extra_heat;   // Basil needs heating even at "cool"
  reg light_needs_boost;       // Basil needs lights even at "low"
  reg soil_needs_early_water;  // Basil/Pea need water earlier
  reg humid_lower_tolerance;   // Sunflower dehumidify earlier
  reg temp_cool_early;         // Pea shoots cool at "optimal"
  
  // Crop profile selector logic
  always @(*) begin
    case (crop_select)
      2'b00: begin  // RADISH - Balanced profile
        temp_low_threshold       = 2'd0;  // Heat at "too cold"
        temp_high_threshold      = 2'd3;  // Cool at "too hot"
        humid_high_threshold     = 2'd3;  // Dehumidify at "too humid"
        light_low_threshold      = 2'd0;  // Lights at "dark"
        soil_low_threshold       = 2'd1;  // Water at "slightly dry"
        temp_needs_extra_heat    = 1'b0;
        light_needs_boost        = 1'b0;
        soil_needs_early_water   = 1'b0;
        humid_lower_tolerance    = 1'b0;
        temp_cool_early          = 1'b0;
      end
      
      2'b01: begin  // BASIL - Warm, humid, bright
        temp_low_threshold       = 2'd0;
        temp_high_threshold      = 2'd3;
        humid_high_threshold     = 2'd3;
        light_low_threshold      = 2'd0;
        soil_low_threshold       = 2'd0;  // Water at "dry"
        temp_needs_extra_heat    = 1'b1;  // Heat even at "cool"
        light_needs_boost        = 1'b1;  // Lights even at "low"
        soil_needs_early_water   = 1'b1;  // More water
        humid_lower_tolerance    = 1'b0;
        temp_cool_early          = 1'b0;
      end
      
      2'b10: begin  // PEA SHOOTS - Cool, moist
        temp_low_threshold       = 2'd0;
        temp_high_threshold      = 2'd2;  // Cool earlier (at "optimal")
        humid_high_threshold     = 2'd3;
        light_low_threshold      = 2'd0;
        soil_low_threshold       = 2'd0;  // Water at "dry"
        temp_needs_extra_heat    = 1'b0;
        light_needs_boost        = 1'b0;
        soil_needs_early_water   = 1'b1;  // More water
        humid_lower_tolerance    = 1'b0;
        temp_cool_early          = 1'b1;  // Cooler preference
      end
      
      2'b11: begin  // SUNFLOWER - Dry, warm
        temp_low_threshold       = 2'd0;
        temp_high_threshold      = 2'd3;
        humid_high_threshold     = 2'd2;  // Dehumidify at "optimal"
        light_low_threshold      = 2'd0;
        soil_low_threshold       = 2'd1;  // Water at "slightly dry"
        temp_needs_extra_heat    = 1'b0;
        light_needs_boost        = 1'b0;
        soil_needs_early_water   = 1'b0;
        humid_lower_tolerance    = 1'b1;  // Lower humidity tolerance
        temp_cool_early          = 1'b0;
      end
    endcase
  end

  // ===========================================================================
  // INTERNAL SIGNALS
  // ===========================================================================
  
  // Sensor status flags
  reg temp_needs_heating;
  reg temp_needs_cooling;
  reg humid_needs_dehumidify;
  reg light_needs_on;
  reg soil_needs_water;
  
  // Heartbeat counter
  reg [24:0] heartbeat_counter;
  
  // Override state
  reg override_active;

  // ===========================================================================
  // HEARTBEAT GENERATION
  // ===========================================================================
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      heartbeat_counter <= 25'd0;
      status_heartbeat <= 1'b0;
    end else if (ena) begin
      if (heartbeat_counter >= (HEARTBEAT_DIV / 2 - 1)) begin
        heartbeat_counter <= 25'd0;
        status_heartbeat <= ~status_heartbeat;
      end else begin
        heartbeat_counter <= heartbeat_counter + 1'd1;
      end
    end
  end

  // ===========================================================================
  // OVERRIDE LOGIC
  // ===========================================================================
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      override_active <= 1'b0;
    end else if (ena) begin
      override_active <= cmd_override;
    end
  end

  // ===========================================================================
  // SENSOR COMPARISON LOGIC
  // ===========================================================================
  
  always @(*) begin
    // Temperature assessment
    temp_needs_heating = (sensor_temperature <= temp_low_threshold) ||
                         (temp_needs_extra_heat && (sensor_temperature == 2'd1));
    
    temp_needs_cooling = (sensor_temperature >= temp_high_threshold) ||
                         (temp_cool_early && (sensor_temperature == 2'd2));
    
    // Humidity assessment
    humid_needs_dehumidify = (sensor_humidity >= humid_high_threshold);
    
    // Light assessment
    light_needs_on = (sensor_light <= light_low_threshold) ||
                     (light_needs_boost && (sensor_light == 2'd1));
    
    // Soil moisture assessment
    soil_needs_water = (sensor_soil_moisture <= soil_low_threshold);
  end

  // ===========================================================================
  // ACTUATOR CONTROL LOGIC
  // ===========================================================================
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_water_pump <= 1'b0;
      ctrl_heater <= 1'b0;
      ctrl_cooler <= 1'b0;
      ctrl_light <= 1'b0;
      ctrl_dehumidifier <= 1'b0;
    end else if (ena) begin
      if (override_active) begin
        // Override active - turn off all actuators
        ctrl_water_pump <= 1'b0;
        ctrl_heater <= 1'b0;
        ctrl_cooler <= 1'b0;
        ctrl_light <= 1'b0;
        ctrl_dehumidifier <= 1'b0;
      end else begin
        // Normal autonomous operation
        ctrl_water_pump <= soil_needs_water;
        ctrl_heater <= temp_needs_heating;
        ctrl_cooler <= temp_needs_cooling;
        ctrl_light <= light_needs_on;
        ctrl_dehumidifier <= humid_needs_dehumidify;
      end
    end
  end

  // ===========================================================================
  // FAULT DETECTION (Placeholder - to be enhanced in Step 3)
  // ===========================================================================
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      flag_fault <= 1'b0;
    end else if (ena) begin
      // Simple fault: heater and cooler both needed (contradiction)
      flag_fault <= temp_needs_heating && temp_needs_cooling;
    end
  end

  // ===========================================================================
  // UART INTERFACE (Placeholder - to be implemented in Step 4)
  // ===========================================================================
  
  assign uart_tx = 1'b1;  // Idle high

  // Suppress unused warnings
  wire _unused = &{FAULT_PERSIST, soil_needs_early_water, humid_lower_tolerance, 1'b0};

endmodule

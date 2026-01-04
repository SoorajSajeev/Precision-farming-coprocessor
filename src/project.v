/*
 * Copyright (c) 2024 SoorajSajeev
 * SPDX-License-Identifier: Apache-2.0
 * 
 * Precision Farming Coprocessor - ENHANCED VERSION
 * With Sensor Filtering and Data Logging
 */

`default_nettype none

// =============================================================================
// TOP-LEVEL MODULE (Tiny Tapeout Wrapper)
// =============================================================================

module tt_um_SoorajSajeev_precision_farming_coprocessor (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  // Pin Assignments
  wire [1:0] sensor_temperature   = ui_in[1:0];
  wire [1:0] sensor_humidity      = ui_in[3:2];
  wire [1:0] sensor_light         = ui_in[5:4];
  wire [1:0] sensor_soil_moisture = ui_in[7:6];
  
  wire       cmd_override = uio_in[0];
  wire [1:0] crop_select  = uio_in[2:1];
  wire       uart_rx      = uio_in[3];
  
  wire ctrl_water_pump, ctrl_heater, ctrl_cooler, ctrl_light;
  wire flag_fault, status_heartbeat, ctrl_dehumidifier, uart_tx;
  
  assign uo_out = {1'b0, ctrl_dehumidifier, status_heartbeat, flag_fault,
                   ctrl_light, ctrl_cooler, ctrl_heater, ctrl_water_pump};
  assign uio_out = {uart_tx, 7'b0};
  assign uio_oe = 8'b1000_0000;

  // Core instantiation
  ag_control_core core_inst (
    .clk(clk), .rst_n(rst_n), .ena(ena),
    .sensor_temperature(sensor_temperature),
    .sensor_humidity(sensor_humidity),
    .sensor_light(sensor_light),
    .sensor_soil_moisture(sensor_soil_moisture),
    .cmd_override(cmd_override),
    .crop_select(crop_select),
    .ctrl_water_pump(ctrl_water_pump),
    .ctrl_heater(ctrl_heater),
    .ctrl_cooler(ctrl_cooler),
    .ctrl_light(ctrl_light),
    .ctrl_dehumidifier(ctrl_dehumidifier),
    .flag_fault(flag_fault),
    .status_heartbeat(status_heartbeat),
    .uart_tx(uart_tx)
  );

  wire _unused = &{uart_rx, uio_in[7:4], 1'b0};

endmodule

// =============================================================================
// CORE CONTROL MODULE WITH FILTERING AND LOGGING
// =============================================================================

module ag_control_core (
    input  wire       clk, rst_n, ena,
    input  wire [1:0] sensor_temperature, sensor_humidity,
                      sensor_light, sensor_soil_moisture,
    input  wire       cmd_override,
    input  wire [1:0] crop_select,
    output reg        ctrl_water_pump, ctrl_heater, ctrl_cooler,
                      ctrl_light, ctrl_dehumidifier,
    output reg        flag_fault, status_heartbeat,
    output wire       uart_tx
);

  // Parameters
  localparam HEARTBEAT_DIV = 25_000_000;
  localparam FILTER_THRESHOLD = 100_000;
  localparam LOG_INTERVAL = 2_500_000;

  // Filtered sensor values
  reg [1:0] temp_filtered, humid_filtered, light_filtered, soil_filtered;
  reg [16:0] temp_stable_count, humid_stable_count, light_stable_count, soil_stable_count;
  reg [1:0] temp_prev, humid_prev, light_prev, soil_prev;

  // Data logging
  reg [1:0] temp_history[0:7], humid_history[0:7], light_history[0:7], soil_history[0:7];
  reg [2:0] history_index;
  reg [21:0] log_counter;
  reg [1:0] temp_min, temp_max, humid_min, humid_max;
  reg [1:0] light_min, light_max, soil_min, soil_max;
  reg [1:0] temp_trend, humid_trend, light_trend, soil_trend;

  // Crop thresholds
  reg [1:0] temp_low_threshold, temp_high_threshold, humid_high_threshold;
  reg [1:0] light_low_threshold, soil_low_threshold;
  reg temp_needs_extra_heat, light_needs_boost, soil_needs_early_water;
  reg humid_lower_tolerance, temp_cool_early;

  // Control signals
  reg temp_needs_heating, temp_needs_cooling, humid_needs_dehumidify;
  reg light_needs_on, soil_needs_water;
  reg [24:0] heartbeat_counter;
  reg override_active;

  // SENSOR FILTERING
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {temp_filtered, humid_filtered, light_filtered, soil_filtered} <= {2'd2, 2'd2, 2'd2, 2'd2};
      {temp_stable_count, humid_stable_count, light_stable_count, soil_stable_count} <= {17'd0, 17'd0, 17'd0, 17'd0};
      {temp_prev, humid_prev, light_prev, soil_prev} <= {2'd2, 2'd2, 2'd2, 2'd2};
    end else if (ena) begin
      // Temperature
      if (sensor_temperature == temp_prev) begin
        if (temp_stable_count < FILTER_THRESHOLD) 
          temp_stable_count <= temp_stable_count + 1'd1;
        else 
          temp_filtered <= sensor_temperature;
      end else begin
        temp_stable_count <= 17'd0;
        temp_prev <= sensor_temperature;
      end
      
      // Humidity
      if (sensor_humidity == humid_prev) begin
        if (humid_stable_count < FILTER_THRESHOLD) 
          humid_stable_count <= humid_stable_count + 1'd1;
        else 
          humid_filtered <= sensor_humidity;
      end else begin
        humid_stable_count <= 17'd0;
        humid_prev <= sensor_humidity;
      end
      
      // Light
      if (sensor_light == light_prev) begin
        if (light_stable_count < FILTER_THRESHOLD) 
          light_stable_count <= light_stable_count + 1'd1;
        else 
          light_filtered <= sensor_light;
      end else begin
        light_stable_count <= 17'd0;
        light_prev <= sensor_light;
      end
      
      // Soil
      if (sensor_soil_moisture == soil_prev) begin
        if (soil_stable_count < FILTER_THRESHOLD) 
          soil_stable_count <= soil_stable_count + 1'd1;
        else 
          soil_filtered <= sensor_soil_moisture;
      end else begin
        soil_stable_count <= 17'd0;
        soil_prev <= sensor_soil_moisture;
      end
    end
  end

  // DATA LOGGING
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      history_index <= 3'd0;
      log_counter <= 22'd0;
      for (i = 0; i < 8; i = i + 1) begin
        temp_history[i] <= 2'd2; humid_history[i] <= 2'd2;
        light_history[i] <= 2'd2; soil_history[i] <= 2'd2;
      end
      {temp_min, temp_max} <= {2'd2, 2'd2};
      {humid_min, humid_max} <= {2'd2, 2'd2};
      {light_min, light_max} <= {2'd2, 2'd2};
      {soil_min, soil_max} <= {2'd2, 2'd2};
      {temp_trend, humid_trend, light_trend, soil_trend} <= {2'b11, 2'b11, 2'b11, 2'b11};
    end else if (ena) begin
      if (log_counter >= LOG_INTERVAL - 1) begin
        log_counter <= 22'd0;
        temp_history[history_index] <= temp_filtered;
        humid_history[history_index] <= humid_filtered;
        light_history[history_index] <= light_filtered;
        soil_history[history_index] <= soil_filtered;
        
        if (temp_filtered < temp_min) temp_min <= temp_filtered;
        if (temp_filtered > temp_max) temp_max <= temp_filtered;
        if (humid_filtered < humid_min) humid_min <= humid_filtered;
        if (humid_filtered > humid_max) humid_max <= humid_filtered;
        if (light_filtered < light_min) light_min <= light_filtered;
        if (light_filtered > light_max) light_max <= light_filtered;
        if (soil_filtered < soil_min) soil_min <= soil_filtered;
        if (soil_filtered > soil_max) soil_max <= soil_filtered;
        
        if (history_index > 0) begin
          temp_trend <= (temp_filtered > temp_history[history_index-1]) ? 2'b01 :
                        (temp_filtered < temp_history[history_index-1]) ? 2'b10 : 2'b00;
          humid_trend <= (humid_filtered > humid_history[history_index-1]) ? 2'b01 :
                         (humid_filtered < humid_history[history_index-1]) ? 2'b10 : 2'b00;
          light_trend <= (light_filtered > light_history[history_index-1]) ? 2'b01 :
                         (light_filtered < light_history[history_index-1]) ? 2'b10 : 2'b00;
          soil_trend <= (soil_filtered > soil_history[history_index-1]) ? 2'b01 :
                        (soil_filtered < soil_history[history_index-1]) ? 2'b10 : 2'b00;
        end
        history_index <= history_index + 1'd1;
      end else 
        log_counter <= log_counter + 1'd1;
    end
  end

  // CROP PROFILES
  always @(*) begin
    case (crop_select)
      2'b00: begin // RADISH
        {temp_low_threshold, temp_high_threshold, humid_high_threshold, 
         light_low_threshold, soil_low_threshold} = {2'd0, 2'd3, 2'd3, 2'd0, 2'd1};
        {temp_needs_extra_heat, light_needs_boost, soil_needs_early_water,
         humid_lower_tolerance, temp_cool_early} = 5'b00000;
      end
      2'b01: begin // BASIL
        {temp_low_threshold, temp_high_threshold, humid_high_threshold,
         light_low_threshold, soil_low_threshold} = {2'd0, 2'd3, 2'd3, 2'd0, 2'd0};
        {temp_needs_extra_heat, light_needs_boost, soil_needs_early_water,
         humid_lower_tolerance, temp_cool_early} = 5'b11100;
      end
      2'b10: begin // PEA SHOOTS
        {temp_low_threshold, temp_high_threshold, humid_high_threshold,
         light_low_threshold, soil_low_threshold} = {2'd0, 2'd2, 2'd3, 2'd0, 2'd0};
        {temp_needs_extra_heat, light_needs_boost, soil_needs_early_water,
         humid_lower_tolerance, temp_cool_early} = 5'b00101;
      end
      2'b11: begin // SUNFLOWER
        {temp_low_threshold, temp_high_threshold, humid_high_threshold,
         light_low_threshold, soil_low_threshold} = {2'd0, 2'd3, 2'd2, 2'd0, 2'd1};
        {temp_needs_extra_heat, light_needs_boost, soil_needs_early_water,
         humid_lower_tolerance, temp_cool_early} = 5'b00010;
      end
    endcase
  end

  // SENSOR COMPARISON (uses filtered values)
  always @(*) begin
    temp_needs_heating = (temp_filtered <= temp_low_threshold) || (temp_needs_extra_heat && temp_filtered == 2'd1);
    temp_needs_cooling = (temp_filtered >= temp_high_threshold) || (temp_cool_early && temp_filtered == 2'd2);
    humid_needs_dehumidify = (humid_filtered >= humid_high_threshold);
    light_needs_on = (light_filtered <= light_low_threshold) || (light_needs_boost && light_filtered == 2'd1);
    soil_needs_water = (soil_filtered <= soil_low_threshold);
  end

  // HEARTBEAT
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {heartbeat_counter, status_heartbeat} <= {25'd0, 1'b0};
    end else if (ena) begin
      if (heartbeat_counter >= (HEARTBEAT_DIV / 2 - 1)) begin
        heartbeat_counter <= 25'd0;
        status_heartbeat <= ~status_heartbeat;
      end else
        heartbeat_counter <= heartbeat_counter + 1'd1;
    end
  end

  // OVERRIDE
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      override_active <= 1'b0;
    else if (ena)
      override_active <= cmd_override;
  end

  // ACTUATOR CONTROL
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {ctrl_water_pump, ctrl_heater, ctrl_cooler, ctrl_light, ctrl_dehumidifier} <= 5'b00000;
    end else if (ena) begin
      if (override_active)
        {ctrl_water_pump, ctrl_heater, ctrl_cooler, ctrl_light, ctrl_dehumidifier} <= 5'b00000;
      else
        {ctrl_water_pump, ctrl_heater, ctrl_cooler, ctrl_light, ctrl_dehumidifier} <=
          {soil_needs_water, temp_needs_heating, temp_needs_cooling, light_needs_on, humid_needs_dehumidify};
    end
  end

  // FAULT DETECTION
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      flag_fault <= 1'b0;
    else if (ena)
      flag_fault <= temp_needs_heating && temp_needs_cooling;
  end

  // UART
  reg [7:0] uart_data;
  reg uart_send, fault_sent;
  wire uart_busy;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {uart_data, uart_send, fault_sent} <= {8'h00, 1'b0, 1'b0};
    end else if (ena) begin
      if (flag_fault && !fault_sent && !uart_busy) begin
        uart_data <= 8'h46;
        uart_send <= 1'b1;
        fault_sent <= 1'b1;
      end else
        uart_send <= 1'b0;
      if (!flag_fault)
        fault_sent <= 1'b0;
    end
  end
  
  uart_tx_simple uart_inst (.clk(clk), .rst_n(rst_n), .data(uart_data), 
                             .send(uart_send), .tx(uart_tx), .busy(uart_busy));

  wire _unused = &{1'b0, soil_needs_early_water, humid_lower_tolerance, temp_trend, humid_trend,
                   light_trend, soil_trend, temp_min, temp_max, humid_min, humid_max,
                   light_min, light_max, soil_min, soil_max};

endmodule

// =============================================================================
// UART TRANSMITTER
// =============================================================================

module uart_tx_simple (
    input  wire       clk, rst_n,
    input  wire [7:0] data,
    input  wire       send,
    output reg        tx, busy
);

  localparam CLKS_PER_BIT = 217;
  localparam [2:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;
  
  reg [2:0] state;
  reg [7:0] clk_count, tx_data;
  reg [2:0] bit_index;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      {state, tx, busy, clk_count, bit_index, tx_data} <= {IDLE, 1'b1, 1'b0, 8'd0, 3'd0, 8'd0};
    end else begin
      case (state)
        IDLE: begin
          {tx, busy, clk_count, bit_index} <= {1'b1, 1'b0, 8'd0, 3'd0};
          if (send) begin
            tx_data <= data;
            {state, busy} <= {START, 1'b1};
          end
        end
        START: begin
          tx <= 1'b0;
          if (clk_count < CLKS_PER_BIT - 1)
            clk_count <= clk_count + 1'd1;
          else begin
            {clk_count, state} <= {8'd0, DATA};
          end
        end
        DATA: begin
          tx <= tx_data[bit_index];
          if (clk_count < CLKS_PER_BIT - 1)
            clk_count <= clk_count + 1'd1;
          else begin
            clk_count <= 8'd0;
            if (bit_index < 7)
              bit_index <= bit_index + 1'd1;
            else begin
              {bit_index, state} <= {3'd0, STOP};
            end
          end
        end
        STOP: begin
          tx <= 1'b1;
          if (clk_count < CLKS_PER_BIT - 1)
            clk_count <= clk_count + 1'd1;
          else begin
            {clk_count, state, busy} <= {8'd0, IDLE, 1'b0};
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule

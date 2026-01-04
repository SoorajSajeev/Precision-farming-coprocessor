
/*
Title: 4-bit SAR Logic
Author: Venkata Ratnam Bhumireddy
Date: 24/06/2024
Description: 

*/

module sarlogic(clk, reset, d, bitout, conv_done);
  input clk;
  input reset;
  input d;
  output wire [3:0] bitout;
  output wire conv_done;
  

  // shift 1 to right and save input - d from MSB
  reg [3:0] bitout_d;
  reg [3:0] bitout_q;
  // HIGH When Conversion is done
  reg conv_done_d;
  reg conv_done_q;
  
  // state register
  reg [2:0] state_d;
  reg [2:0] state_q;
  
  assign bitout = bitout_q;
  assign conv_done = conv_done_q;
  
  always @(posedge clk) begin
    if(reset)
      begin
        bitout_q <= 4'b0000;
        conv_done_q <= 1'b0;
      end
    else
      bitout_q <= bitout_d;
    conv_done_q <= conv_done_d;
  end
  
  always @(posedge clk) begin
    if(reset)
      begin
        state_q <= 3'b000;
      end
    else
      state_q <= state_d;
  end
  
  always @(*) begin
    case(state_q)
      3'b000: 
        begin
          bitout_d = 4'b1000;
          conv_done_d = 0;
          state_d = state_q + 1;
        end
      3'b001: 
        begin
          bitout_d[1:0] = bitout_q[1:0];
          bitout_d[2] = 1'b1;
          bitout_d[3] = d;
          conv_done_d = 0;
          state_d = state_q + 1;
        end
      3'b010: 
        begin
          bitout_d[0] = bitout_q[0];
          bitout_d[1] = 1'b1;
          bitout_d[2] = d;
          bitout_d[3] = bitout_q[3];
          conv_done_d = 0;
          state_d = state_q + 1;
        end
      3'b011: 
        begin
          bitout_d[0] = 1'b1;
          bitout_d[1] = d;
          bitout_d[3:2] = bitout_q[3:2];
          conv_done_d = 0;
          state_d = state_q + 1;
        end
      3'b100: 
        begin
          bitout_d[3:1] = bitout_q[3:1];
          bitout_d[0] = d;
          conv_done_d = 1;
          state_d = 3'b000;
        end
      default: 
        begin
          bitout_d = bitout_q;
          conv_done_d = 0;
          state_d = 3'b000;
        end
    endcase
  end
endmodule

// Copyright 2024 Cisco and/or its affiliates
// SPDX-License-Identifier: Apache-2.0

module sample_output (
    input clk,  // clock
    input rst,  // reset
    input ext_clock,
    input ext_data, 
    output [7:0] out,
    output out_rdy,
    output clk_deactivate
  );
  
  reg out_rdy_d = 0, out_rdy_q = 0;
  reg [7:0] out_d = 0, out_q = 0;
  reg [2:0] counter_d = 0, counter_q = 0;
  // Testing this rising edge detector
  reg [2:0] rising_edge_d = 3'b111, rising_edge_q = 3'b111;
  wire fast_reset;
  
  clock_reset clock_reset(.clk(clk), .rst(rst), .ext_clk(ext_clock), .out(clk_deactivate));
  clock_reset #(.COMPARISON(8'h05)) clock_reset_fast(.clk(clk), .rst(rst), .ext_clk(ext_clock), .out(fast_reset));
   
  assign out_rdy = out_rdy_q == 1'b1;
  assign out = out_q;
  
  always @* begin
    // Default values, or bad things happen
    out_d = out_q;
    out_rdy_d = out_rdy_q;
    rising_edge_d = {rising_edge_q[1:0], ext_clock};
    counter_d = counter_q;
    
    // We only want this code to run when the clock is active
    if (!clk_deactivate) begin
      // This code just ensures we have a rising edge that *hopefully* isn't due to line jitter, but isn't too far past when we can sample valid data
      if (rising_edge_q == 3'b011) begin
      // Shift in our bit (flipped due to active low)
        out_d = {out_q[6:0], ~ext_data};
        // Move our bit counter
        counter_d = counter_q + 1;
        
        // If we have 8 bits, then our byte is ready
        if (counter_q == 7) begin
          out_rdy_d = 1'b1;
        end else begin
          out_rdy_d = 1'b0;
        end
      end
    end
    
  end

  
  /* Sequential Logic */
  always @(posedge clk) begin
    if (rst || clk_deactivate) begin
      out_q <= 0;
      counter_q <= 0;
      out_rdy_q <= 0;
      rising_edge_q <= 3'b111;
     
    end else begin
      out_q <= out_d;
      if (fast_reset) begin
        counter_q <= 0;
      end else begin
        counter_q <= counter_d;
      end   
      out_rdy_q <= out_rdy_d;
      rising_edge_q <= rising_edge_d;
    end
  end
  
endmodule

// Copyright 2024 Cisco and/or its affiliates
// SPDX-License-Identifier: Apache-2.0

module clock_reset 
    #(
    parameter COMPARISON = 8'h80
    )
    (
    input clk,  // clock
    input rst,  // reset
    input ext_clk,
    output out
  );
  
  reg [7:0] counter;
  
  assign out = counter > COMPARISON;

  
  /* Sequential Logic */
  always @(posedge clk) begin
    if (rst) begin
        counter <= 0;
    end else begin
        
        if (ext_clk == 1) begin
            // This prevents us from overflowing our counter, which we don't want to do
            if (counter[7] && counter[6]) begin
                counter <= counter;
            end else begin
                counter <= counter + 1;
            end
        end else begin
            counter <= 0;
        end
        
    end
  end
  
endmodule

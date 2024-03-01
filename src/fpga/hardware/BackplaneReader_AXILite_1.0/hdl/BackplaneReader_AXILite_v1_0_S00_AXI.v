// Copyright 2024 Cisco and/or its affiliates
// SPDX-License-Identifier: Apache-2.0

`timescale 1 ns / 1 ps

	module BackplaneReader_AXILite_v1_0_S00_AXI #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 7
	)
	(
		// Users to add ports here
		input wire clk,
		input wire ext_clock,
		input wire ext_data,
		input wire backplane_rst,
		output wire dataReady_interrupt,
		output wire [7:0] out,
		output wire out_rdy,
        output wire [31:0] holdingData,
        output wire [6:0] memoryIndex,
        output wire [1:0] indexCounter,
        output wire [31:0] mem,
        output wire clk_deactivate,

		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
    		// privilege and security level of the transaction, and whether
    		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
    		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the slave is ready
    		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave) 
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.    
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
    		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
    		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
    		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
    		// and security level of the transaction, and whether the
    		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
    		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the slave is
    		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
    		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
    		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    		// accept the read data and response information.
		input wire  S_AXI_RREADY
	);

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 4;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 32
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg6;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg7;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg8;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg9;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg10;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg11;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg12;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg13;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg14;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg15;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg16;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg17;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg18;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg19;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg20;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg21;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg22;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg23;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg24;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg25;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg26;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg27;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg28;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg29;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg30;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg31;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg32;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg33;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg34;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg34;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg35;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg36;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg37;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg38;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg39;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg40;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg41;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg42;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg43;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg44;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg45;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg46;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg47;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg48;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg49;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg50;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg51;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg52;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg53;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg54;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg55;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg56;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg57;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg58;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg59;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg60;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg61;
    reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg62;
	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;
	reg	 aw_en;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
  

	// Implement axi_arready generation
	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when S_AXI_ARVALID is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    

	// Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	        5'h00   : reg_data_out <= slv_reg0;
	        5'h01   : reg_data_out <= slv_reg1;
	        5'h02   : reg_data_out <= slv_reg2;
	        5'h03   : reg_data_out <= slv_reg3;
	        5'h04   : reg_data_out <= slv_reg4;
	        5'h05   : reg_data_out <= slv_reg5;
	        5'h06   : reg_data_out <= slv_reg6;
	        5'h07   : reg_data_out <= slv_reg7;
	        5'h08   : reg_data_out <= slv_reg8;
	        5'h09   : reg_data_out <= slv_reg9;
	        5'h0A   : reg_data_out <= slv_reg10;
	        5'h0B   : reg_data_out <= slv_reg11;
	        5'h0C   : reg_data_out <= slv_reg12;
	        5'h0D   : reg_data_out <= slv_reg13;
	        5'h0E   : reg_data_out <= slv_reg14;
	        5'h0F   : reg_data_out <= slv_reg15;
	        5'h10   : reg_data_out <= slv_reg16;
	        5'h11   : reg_data_out <= slv_reg17;
	        5'h12   : reg_data_out <= slv_reg18;
	        5'h13   : reg_data_out <= slv_reg19;
	        5'h14   : reg_data_out <= slv_reg20;
	        5'h15   : reg_data_out <= slv_reg21;
	        5'h16   : reg_data_out <= slv_reg22;
	        5'h17   : reg_data_out <= slv_reg23;
	        5'h18   : reg_data_out <= slv_reg24;
	        5'h19   : reg_data_out <= slv_reg25;
	        5'h1A   : reg_data_out <= slv_reg26;
	        5'h1B   : reg_data_out <= slv_reg27;
	        5'h1C   : reg_data_out <= slv_reg28;
	        5'h1D   : reg_data_out <= slv_reg29;
	        5'h1E   : reg_data_out <= slv_reg30;
	        5'h1F   : reg_data_out <= slv_reg31;
	        5'h20   : reg_data_out <= slv_reg32;
	        5'h21   : reg_data_out <= slv_reg33;
	        5'h22   : reg_data_out <= slv_reg34;
	        5'h23   : reg_data_out <= slv_reg34;
	        5'h24   : reg_data_out <= slv_reg35;
	        5'h25   : reg_data_out <= slv_reg36;
	        5'h26   : reg_data_out <= slv_reg37;
	        5'h27   : reg_data_out <= slv_reg38;
	        5'h28   : reg_data_out <= slv_reg39;
	        5'h29   : reg_data_out <= slv_reg40;
	        5'h2A   : reg_data_out <= slv_reg41;
	        5'h2B   : reg_data_out <= slv_reg42;
	        5'h2C   : reg_data_out <= slv_reg43;
	        5'h2D   : reg_data_out <= slv_reg44;
	        5'h2E   : reg_data_out <= slv_reg45;
	        5'h2F   : reg_data_out <= slv_reg46;
	        5'h30   : reg_data_out <= slv_reg47;
	        5'h31   : reg_data_out <= slv_reg48;
	        5'h32   : reg_data_out <= slv_reg49;
	        5'h33   : reg_data_out <= slv_reg50;
	        5'h34   : reg_data_out <= slv_reg51;
	        5'h35   : reg_data_out <= slv_reg52;
	        5'h36   : reg_data_out <= slv_reg53;
	        5'h37   : reg_data_out <= slv_reg54;
	        5'h38   : reg_data_out <= slv_reg55;
	        5'h39   : reg_data_out <= slv_reg56;
	        5'h3A   : reg_data_out <= slv_reg57;
	        5'h3B   : reg_data_out <= slv_reg58;
	        5'h3C   : reg_data_out <= slv_reg59;
	        5'h3D   : reg_data_out <= slv_reg60;
	        5'h3E   : reg_data_out <= slv_reg61;
	        5'h3F   : reg_data_out <= slv_reg62;
	        default : reg_data_out <= 0;
	      endcase
	end
	
    // Output register or memory read data
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end 
	  else
	    begin    
	      // When there is a valid read address (S_AXI_ARVALID) with 
	      // acceptance of read address by the slave (axi_arready), 
	      // output the read dada 
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end   
	    end
	end   
	
//    reg [31:0] backplaneData_q[6:0], backplaneData_d[6:0];
//	wire [7:0] out;
//	wire out_rdy, clk_deactivate;
//	wire clk_deactivate;
	reg [6:0] memoryIndex_q = 0, memoryIndex_d = 0;
//    reg [6:0] memoryIndex = 0;
    reg [1:0] indexCounter_q = 0, indexCounter_d = 0;
    reg [31:0] holdingData_q = 0, holdingData_d = 0;
    reg out_done_q = 0, out_done_d = 0;
    reg interrupt_flicker_q = 0, interrupt_flicker_d = 0;
    reg flicker_done_q = 0, flicker_done_d = 0;
	integer index;

 

	// Add user logic here
	
    // We will probably need some sort of counter for the number of bytes that are recv'd so we only attempt to read that many from the CPU
	
//	assign dataReady_interrupt = clk_deactivate;
//	assign dataReady_interrupt = interrupt_flicker_q == 1;
    assign dataReady_interrupt = clk_deactivate & interrupt_flicker_q;
	assign holdingData = holdingData_q;
	assign memoryIndex = memoryIndex_q;
	assign indexCounter = indexCounter_q;
	assign mem = slv_reg0;
	
	sample_output sample_output(
        .clk(clk),  // clock
        .rst(backplane_rst),  // reset
        .ext_clock(ext_clock),
        .ext_data(ext_data), 
        .out(out),
        .out_rdy(out_rdy),
        .clk_deactivate(clk_deactivate));
 
    
    always @* begin
        memoryIndex_d = memoryIndex_q;
        holdingData_d = holdingData_q;
        indexCounter_d = indexCounter_q;
        interrupt_flicker_d = interrupt_flicker_q;
        flicker_done_d = flicker_done_q;
        
        if ( out_rdy  && out_done_q == 0) begin
            holdingData_d = {holdingData_q[23:0], out};
            
            indexCounter_d = indexCounter_q + 1;
            if (indexCounter_q == 3) begin
                slv_reg31 = memoryIndex_q;
                
                case ( memoryIndex_q )
                // This is just a hack so that endianess is what you would expect over the network. We don't have to do this.
                // This cause a slow down enough that it didn't end up working, so weird endianess it is
                    5'h00   : slv_reg0 = holdingData_q;
                    5'h01   : slv_reg1 = holdingData_q;
                    5'h02   : slv_reg2 = holdingData_q;
                    5'h03   : slv_reg3 = holdingData_q;
                    5'h04   : slv_reg4 = holdingData_q;
                    5'h05   : slv_reg5 = holdingData_q;
                    5'h06   : slv_reg6 = holdingData_q;
                    5'h07   : slv_reg7 = holdingData_q;
                    5'h08   : slv_reg8 = holdingData_q;
                    5'h09   : slv_reg9 = holdingData_q;
                    5'h0A   : slv_reg10 = holdingData_q;
                    5'h0B   : slv_reg11 = holdingData_q;
                    5'h0C   : slv_reg12 = holdingData_q;
                    5'h0D   : slv_reg13 = holdingData_q;
                    5'h0E   : slv_reg14 = holdingData_q;
                    5'h0F   : slv_reg15 = holdingData_q;
                    5'h10   : slv_reg16 = holdingData_q;
                    5'h11   : slv_reg17 = holdingData_q;
                    5'h12   : slv_reg18 = holdingData_q;
                    5'h13   : slv_reg19 = holdingData_q;
                    5'h14   : slv_reg20 = holdingData_q;
                    5'h15   : slv_reg21 = holdingData_q;
                    5'h16   : slv_reg22 = holdingData_q;
                    5'h17   : slv_reg23 = holdingData_q;
                    5'h18   : slv_reg24 = holdingData_q;
                    5'h19   : slv_reg25 = holdingData_q;
                    5'h1A   : slv_reg26 = holdingData_q;
                    5'h1B   : slv_reg27 = holdingData_q;
                    5'h1C   : slv_reg28 = holdingData_q;
                    5'h1D   : slv_reg29 = holdingData_q;
                    5'h1E   : slv_reg30 = holdingData_q;
                    5'h1F   : slv_reg31 = holdingData_q;
                    5'h20   : slv_reg32 = holdingData_q;
                    5'h21   : slv_reg33 = holdingData_q;
                    5'h22   : slv_reg34 = holdingData_q;
                    5'h23   : slv_reg34 = holdingData_q;
                    5'h24   : slv_reg35 = holdingData_q;
                    5'h25   : slv_reg36 = holdingData_q;
                    5'h26   : slv_reg37 = holdingData_q;
                    5'h27   : slv_reg38 = holdingData_q;
                    5'h28   : slv_reg39 = holdingData_q;
                    5'h29   : slv_reg40 = holdingData_q;
                    5'h2A   : slv_reg41 = holdingData_q;
                    5'h2B   : slv_reg42 = holdingData_q;
                    5'h2C   : slv_reg43 = holdingData_q;
                    5'h2D   : slv_reg44 = holdingData_q;
                    5'h2E   : slv_reg45 = holdingData_q;
                    5'h2F   : slv_reg46 = holdingData_q;
                    5'h30   : slv_reg47 = holdingData_q;
                    5'h31   : slv_reg48 = holdingData_q;
                    5'h32   : slv_reg49 = holdingData_q;
                    5'h33   : slv_reg50 = holdingData_q;
                    5'h34   : slv_reg51 = holdingData_q;
                    5'h35   : slv_reg52 = holdingData_q;
                    5'h36   : slv_reg53 = holdingData_q;
                    5'h37   : slv_reg54 = holdingData_q;
                    5'h38   : slv_reg55 = holdingData_q;
                    5'h39   : slv_reg56 = holdingData_q;
                    5'h3A   : slv_reg57 = holdingData_q;
                    5'h3B   : slv_reg58 = holdingData_q;
                    5'h3C   : slv_reg59 = holdingData_q;
                    5'h3D   : slv_reg60 = holdingData_q;
                    5'h3E   : slv_reg61 = holdingData_q;
                    5'h3F   : slv_reg62 = memoryIndex_q;
                endcase
                
                memoryIndex_d = memoryIndex_q + 1;
            end
            
            out_done_d = 1;
        end
        else begin
            if ( out_rdy == 0 && out_done_q == 1) begin
                out_done_d = 0;
            end
        end
        
        if (clk_deactivate == 1 && interrupt_flicker_q == 0 && flicker_done_q == 0) begin
//            interrupt_flicker_d = interrupt_flicker_q + 1;
            interrupt_flicker_d = 1;
        end
        else if (clk_deactivate == 1 && interrupt_flicker_q == 1 && flicker_done_q == 0) begin 
            flicker_done_d = 1;
            interrupt_flicker_d = 0;
        end
        else if (clk_deactivate == 0) begin
            flicker_done_d = 0;
            interrupt_flicker_d = 0;
        end
    end
    
        
    always @(posedge clk) begin
        if (backplane_rst || clk_deactivate) begin
            memoryIndex_q <= 0;
            indexCounter_q <= 0;
            holdingData_q <= 0;
            out_done_q <= 0;
            
            interrupt_flicker_q <= interrupt_flicker_d;
            flicker_done_q <= flicker_done_d;
        end
        else begin
            memoryIndex_q <= memoryIndex_d;
            indexCounter_q <= indexCounter_d;
            holdingData_q <= holdingData_d;
            out_done_q <= out_done_d;
            interrupt_flicker_q <= interrupt_flicker_d;
            flicker_done_q <= flicker_done_d;
            
            slv_reg0 <= slv_reg0;
            slv_reg1 <= slv_reg1;
            slv_reg2 <= slv_reg2;
            slv_reg3 <= slv_reg3;
            slv_reg4 <= slv_reg4;
            slv_reg5 <= slv_reg5;
            slv_reg6 <= slv_reg6;
            slv_reg7 <= slv_reg7;
            slv_reg8 <= slv_reg8;
            slv_reg9 <= slv_reg9;
            slv_reg10 <= slv_reg10;
            slv_reg11 <= slv_reg11;
            slv_reg12 <= slv_reg12;
            slv_reg13 <= slv_reg13;
            slv_reg14 <= slv_reg14;
            slv_reg15 <= slv_reg15;
            slv_reg16 <= slv_reg16;
            slv_reg17 <= slv_reg17;
            slv_reg18 <= slv_reg18;
            slv_reg19 <= slv_reg19;
            slv_reg20 <= slv_reg20;
            slv_reg21 <= slv_reg21;
            slv_reg22 <= slv_reg22;
            slv_reg23 <= slv_reg23;
            slv_reg24 <= slv_reg24;
            slv_reg25 <= slv_reg25;
            slv_reg26 <= slv_reg26;
            slv_reg27 <= slv_reg27;
            slv_reg28 <= slv_reg28;
            slv_reg29 <= slv_reg29;
            slv_reg30 <= slv_reg30;
            slv_reg31 <= slv_reg31;
            slv_reg32 <= slv_reg32;
            slv_reg33 <= slv_reg33;
            slv_reg34 <= slv_reg34;
            slv_reg34 <= slv_reg34;
            slv_reg35 <= slv_reg35;
            slv_reg36 <= slv_reg36;
            slv_reg37 <= slv_reg37;
            slv_reg38 <= slv_reg38;
            slv_reg39 <= slv_reg39;
            slv_reg40 <= slv_reg40;
            slv_reg41 <= slv_reg41;
            slv_reg42 <= slv_reg42;
            slv_reg43 <= slv_reg43;
            slv_reg44 <= slv_reg44;
            slv_reg45 <= slv_reg45;
            slv_reg46 <= slv_reg46;
            slv_reg47 <= slv_reg47;
            slv_reg48 <= slv_reg48;
            slv_reg49 <= slv_reg49;
            slv_reg50 <= slv_reg50;
            slv_reg51 <= slv_reg51;
            slv_reg52 <= slv_reg52;
            slv_reg53 <= slv_reg53;
            slv_reg54 <= slv_reg54;
            slv_reg55 <= slv_reg55;
            slv_reg56 <= slv_reg56;
            slv_reg57 <= slv_reg57;
            slv_reg58 <= slv_reg58;
            slv_reg59 <= slv_reg59;
            slv_reg60 <= slv_reg60;
            slv_reg61 <= slv_reg61;
            slv_reg62 <= slv_reg62;
        
        end 
        
    end
    
    // User logic ends
    
    endmodule

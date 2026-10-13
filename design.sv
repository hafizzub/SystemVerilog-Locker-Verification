// =================================================================
// PROJECT: Register Controller Design (reg_ctrl.sv)
// PURPOSE: A 256x16 configuration memory that handles deposits (writes) 
//          and withdrawals (reads) with delay indicators.
// =================================================================

module reg_ctrl 
  # (
     parameter ADDR_WIDTH   = 8,     // Address lines for choosing drawers (0 to 255)
     parameter DATA_WIDTH   = 16,    // Size of the data stored in each locker
     parameter DEPTH        = 256,   // Total number of drawers
     parameter RESET_VAL    = 16'h1234 // Default initialized state value
  )
  ( 
    input                    clk,    // System heartbeat (clock)
    input                    rstn,   // Emergency Reset (active-low)
    input [ADDR_WIDTH-1:0]  addr,   // Drawer Address lever
    input                    sel,    // System active selector
    input                    wr,     // Mode toggle (1 = Write, 0 = Read)
    input [DATA_WIDTH-1:0]  wdata,  // Input shelf (Write data)
    output reg [DATA_WIDTH-1:0] rdata, // Output tray (Read data)
    output reg               ready   // Indicator bulb (1 = Free, 0 = Busy)
  );

  // The 256 storage drawers (registers)
  reg [DATA_WIDTH-1:0] ctrl [DEPTH];

  reg  ready_dly; // History delay indicator flag
  wire ready_pe;  // Task complete notification wire

  // 1. Data deposit and withdrawal control block
  always @ (posedge clk) begin
    if (!rstn) begin
      for (int i = 0; i < DEPTH; i += 1) begin
        ctrl[i] <= RESET_VAL; // set default value to 1234 on Reset
      end
    end else begin
      if (sel & ready & wr) begin
        ctrl[addr] <= wdata; // deposit CAFE into selected drawer
      end

      if (sel & ready & !wr) begin
        rdata <= ctrl[addr]; // fetch and put on Output tray rdata
      end else begin
        rdata <= 0;          // idle output safety reset
      end
    end
  end

  // 2. Delay Indicator control loop
  always @ (posedge clk) begin
    if (!rstn) begin
      ready <= 1; // system free on start
    end else begin
      if (sel & ready_pe) begin
        ready <= 1; // transition back to available
      end
      if (sel & ready & !wr) begin
        ready <= 0; // READ request trigger delay wait (busy flag)
      end
    end
  end

  // 3. Delay history tracker D-FF
  always @ (posedge clk) begin
    if (!rstn) ready_dly <= 1;
    else ready_dly <= ready;
  end

  // 4. Edge change detection trigger
  assign ready_pe = ~ready & ready_dly;

endmodule

// =================================================================
// PROJECT: Register Controller Verification Suite (testbench.sv)
// METHODOLOGY: Constrained-Random, Automated Environment using Generator,
//              Driver, Monitor, and Scoreboard (OOP & Verification concepts).
// =================================================================

// 1. TRANSACTION OBJECT: The Job slip
class reg_item;
  rand bit [7:0]  addr;  // Random target address selection
  rand bit [15:0] wdata; // Random write-data payload
       bit [15:0] rdata; // read payload (hardware output)
  rand bit        wr;    // task mode selector: 1 = write, 0 = read

  function void print(string tag="");
    $display ("T=%0t [%s] addr=0x%0h wr=%0d wdata=0x%0h rdata=0x%0h", 
              $time, tag, addr, wr, wdata, rdata);
  endfunction
endclass

// 2. GENERATOR: The Automatic Slip-maker (Automation Engine)
class generator;
  int   loop = 10;   // No of operations logic 
  event drv_done;    // Sync handshake notification
  mailbox drv_mbx;   // Mailbox to driver

  task run();
    for (int i = 0; i < loop; i++) begin
      reg_item item = new;
      item.randomize(); // generate automatic constraints and values
      $display ("T=%0t [Generator] Loop:%0d/%0d create next item", $time, i+1, loop);
      drv_mbx.put(item);
      $display ("T=%0t [Generator] Wait for driver to be done", $time);
      @(drv_done); // Hold until runner completed
    end
  endtask
endclass

// 3. DRIVER: The active runner Robot (Waiter)
class driver;
  virtual reg_if vif;
  event drv_done;
  mailbox drv_mbx;

  task run();
    $display ("T=%0t [Driver] starting ...", $time);
    @ (posedge vif.clk);

    forever begin
      reg_item item;
      $display ("T=%0t [Driver] waiting for item ...", $time);
      drv_mbx.get(item); // withdraw packet from generator queue
      item.print("Driver");
      
      vif.sel   <= 1; // start selection trigger
      vif.addr  <= item.addr;
      vif.wr    <= item.wr;
      vif.wdata <= item.wdata;
      @ (posedge vif.clk); // Clock pulse trace capture start
      
      while (!vif.ready) begin // delay loop wait
        $display ("T=%0t [Driver] wait until ready is high", $time);
        @(posedge vif.clk);
      end

      vif.sel <= 0; // complete release
      ->drv_done;   // notifier event high
    end
  endtask
endclass

// 4. MONITOR: The independent Spy camera Robot
class monitor;
  virtual reg_if vif;
  mailbox scb_mbx; // Scoreboard buffer mailbox

  task run();
    $display ("T=%0t [Monitor] starting ...", $time);

    forever begin
      @ (posedge vif.clk);
      if (vif.sel) begin // Capture on interface activation 
        reg_item item = new;
        item.addr  = vif.addr;
        item.wr    = vif.wr;
        item.wdata = vif.wdata;

        if (!vif.wr) begin // extra 1 clock delay tracker for reads
          @(posedge vif.clk);
          item.rdata = vif.rdata;
        end
        item.print("Monitor");
        scb_mbx.put(item); // submit check request
      end
    end
  endtask
endclass

// 5. SCOREBOARD: The Auditor (Validation Engine)
class scoreboard;
  mailbox scb_mbx;
  reg_item refq[256]; // Checking list registers (Memory index tracker)

  task run();
    forever begin
      reg_item item;
      scb_mbx.get(item); // fetch tracker report from Monitor
      item.print("Scoreboard");

      if (item.wr) begin // Store action on Write
        if (refq[item.addr] == null)
          refq[item.addr] = new;

        refq[item.addr] = item;
        $display ("T=%0t [Scoreboard] Store addr=0x%0h wr=0x%0h data=0x%0h", $time, item.addr, item.wr, item.wdata);
      end

      if (!item.wr) begin // Validate target on Read operations
        if (refq[item.addr] == null)
          if (item.rdata != 16'h1234) // RESET check defaults matching
            $display ("T=%0t [Scoreboard] ERROR! First time read, addr=0x%0h exp=1234 act=0x%0h", $time, item.addr, item.rdata);
          else
            $display ("T=%0t [Scoreboard] PASS! First time read, addr=0x%0h exp=1234 act=0x%0h", $time, item.addr, item.rdata);
        else
          if (item.rdata != refq[item.addr].wdata) // do results match historical records?
            $display ("T=%0t [Scoreboard] ERROR! addr=0x%0h exp=0x%0h act=0x%0h", $time, item.addr, refq[item.addr].wdata, item.rdata);
          else
            $display ("T=%0t [Scoreboard] PASS! addr=0x%0h exp=0x%0h act=0x%0h", $time, item.addr, refq[item.addr].wdata, item.rdata);
      end
    end
  endtask
endclass

// 6. ENVIRONMENTS: standard vs. automated
class env;
  driver d0; monitor m0; scoreboard s0; mailbox scb_mbx; virtual reg_if vif;

  function new();
    d0 = new; m0 = new; s0 = new; scb_mbx = new();
  endfunction

  virtual task run();
    d0.vif = vif; m0.vif = vif;
    m0.scb_mbx = scb_mbx; s0.scb_mbx = scb_mbx;
    fork s0.run(); d0.run(); m0.run(); join_any
  endtask
endclass

// Environment wrapper supporting Automation (Generator connected)
class env_w_gen extends env;
  generator g0; event drv_done; mailbox drv_mbx;

  function new();
    super.new();
    g0 = new; drv_mbx = new;
  endfunction

  virtual task run();
    d0.vif = vif; m0.vif = vif;
    d0.drv_mbx = drv_mbx; g0.drv_mbx = drv_mbx;
    m0.scb_mbx = scb_mbx; s0.scb_mbx = scb_mbx;
    d0.drv_done = drv_done; g0.drv_done = drv_done;
    
    fork s0.run(); d0.run(); m0.run(); g0.run(); join_any
  endtask
endclass

// 7. TESTING CONNECTIONS (Standard vs custom Randomized testing loops)
interface reg_if (input bit clk);
  logic rstn, wr, sel, ready;
  logic [7:0] addr;
  logic [15:0] wdata, rdata;
endinterface

class test;
  env e0; mailbox drv_mbx;
  function new(); drv_mbx = new(); e0 = new(); endfunction
  virtual task run(); e0.d0.drv_mbx = drv_mbx; fork e0.run(); join_none apply_stim(); endtask
  virtual task apply_stim();
    reg_item item;
    item = new; item.randomize() with { addr == 8'haa; wr == 1; }; drv_mbx.put(item);
    item = new; item.randomize() with { addr == 8'haa; wr == 0; }; drv_mbx.put(item);
  endtask
endclass

class rand_test extends test; // generates 20 parallel constrained loops testing patterns
  virtual task apply_stim();
    for (int i = 0; i < 20; i++) begin
      reg_item item = new;
      item.randomize();
      drv_mbx.put(item);
    end
  endtask
endclass

class new_test;
  env_w_gen e0;
  function new(); e0 = new(); endfunction
  virtual task run(); fork e0.run(); join_none endtask
endclass

// 8. TESTBENCH TOP: The central start point
module tb;
  reg clk;
  always #10 clk = ~clk; // clk pulsing on posedge/negedge ticks
  reg_if _if (clk);

  reg_ctrl u0 (.clk (clk), .addr(_if.addr), .rstn(_if.rstn), .sel(_if.sel), .wr(_if.wr), .wdata(_if.wdata), .rdata(_if.rdata), .ready(_if.ready));

  initial begin
    test t0; new_test t1; rand_test t2; // standard declaration variables

    clk <= 0; _if.rstn <= 0; _if.sel <= 0;
    #20 _if.rstn <= 1; // wait clock resetting, then proceed

    t0 = new; t0.e0.vif = _if;
    // t0.run(); // Standard manual write read pairs testing loop
    
    t1 = new; t1.e0.vif = _if;
    // t1.run(); // Automated 10-transfer random Generator
    
    t2 = new; t2.e0.vif = _if;
    t2.run(); // Randomized Custom multi data verification run loop
    
    #500 $finish; // safe simulation finish parameter trigger at T520ns
  end

  initial begin
    $dumpvars; $dumpfile("dump.vcd");
  end
endmodule

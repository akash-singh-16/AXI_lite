`timescale 1ns / 1ps

class transaction;
  randc bit op;
  rand bit [31:0] awaddr,wdata,araddr;
  bit [31:0] rdata;
  bit[1:0] wresp,rresp;
  
  constraint valid_addr_range {awaddr==1; araddr==1;}
  constraint valid_data_range {wdata<12; rdata<12;}
endclass

class generator;
  transaction tr;
  mailbox #(transaction) mbx;
  event done;
  event sconext;
  int count;
  
  function new(mailbox #(transaction) mbx);
    this.mbx=mbx;
    tr=new();
  endfunction
  
  task run();
    repeat(count) begin
      assert(tr.randomize) else $error("Randomization Failed");
      $display("[GEN] : OP = %0d, awaddr = %0d, Wdata = %0d, araddr = %0d", tr.op,tr.awaddr,tr.wdata,tr.araddr);
      mbx.put(tr);
      @(sconext);
    end
    ->done;
  endtask
endclass

class driver;
  virtual axi_if vif;
  transaction tr;
  
  mailbox #(transaction) mbxgd,mbxdm;
  
  function new(mailbox #(transaction) mbxgd,mbxdm);
    this.mbxdm=mbxdm;
    this.mbxgd=mbxgd;
  endfunction
  
  task reset();
    vif.resetn<=0;
    vif.awvalid<=0;
    vif.awaddr<=0;
    vif.wvalid<=0;
    vif.wdata<=0;
    vif.bready<=0;
    vif.arvalid<=0;
    vif.araddr<=0;
    repeat(5) @(posedge vif.clk);
    vif.resetn<=1;
    $display("[DRV] : Reset Done");
    $display("----------------------------------");
  endtask
  
  task write_data(input transaction tr);
    $display("[DRV] : OP = %0d, awaddr = %0d, wdata= %0d",tr.op,tr.awaddr,tr.wdata);
    mbxdm.put(tr);
    vif.resetn<=1;
    vif.awvalid<=1;
    vif.arvalid<=0;
    vif.araddr<=0;
    vif.awaddr<=tr.awaddr;
    @(negedge vif.awready);
	vif.awvalid<=0;
    vif.awaddr<=0;
    vif.wvalid<=1;
    vif.wdata<=tr.wdata;
    @(negedge vif.wready);
    vif.wvalid<=0;
    vif.wdata<=0;
    vif.bready<=1;
    vif.rready<=0;
    @(negedge vif.bvalid);
    vif.bready<=0;
  endtask
  
  task read_data(input transaction tr);
    $display("[DRV] : OP = %0d, araddr = %0d", tr.op,tr.araddr);
    mbxdm.put(tr);
    vif.resetn<=1;
    vif.awvalid<=0;
    vif.awaddr<=0;
    vif.wvalid<=0;
    vif.wdata<=0;
    vif.bready<=0;
    vif.arvalid<=1;
    vif.araddr<=tr.araddr;
    @(negedge vif.arready);
    vif.arvalid<=0;
    vif.araddr<=0;
    vif.rready<=1;
    @(negedge vif.rvalid);
    vif.rready<=0;
  endtask
  
  task run();
    forever begin
      mbxgd.get(tr);
      @(posedge vif.clk);
      if(tr.op) write_data(tr);
      else read_data(tr);
    end
  endtask
endclass

class monitor;
  virtual axi_if vif;
  transaction tr,trd;
  mailbox #(transaction) mbxms,mbxdm;
  
  function new(mailbox #(transaction) mbxms,mbxdm);
    this.mbxms=mbxms;
    this.mbxdm=mbxdm;
  endfunction
  
  task run();
    tr=new();
    forever begin
      @(posedge vif.clk);
      mbxdm.get(trd);
      if(trd.op) begin
        tr.op=trd.op;
        tr.awaddr=trd.awaddr;
        tr.wdata=trd.wdata;
        @(posedge vif.bvalid);
        tr.wresp=vif.wresp;
        @(negedge vif.bvalid);
        $display("[MON] : OP = %d, awaddr = %0d, Wdata = %0d, wresp = %0d",tr.op,tr.awaddr,tr.wdata,tr.wresp);
        mbxms.put(tr);
      end
      else begin
        tr.op=trd.op;
        tr.araddr=trd.araddr;
        @(posedge vif.rvalid);
        tr.rdata=vif.rdata;
        tr.rresp=vif.rresp;
        @(negedge vif.rvalid);
        $display("[MON] : OP : %0d, araddr = %0d, rdata = %0d, rresp = %0d",tr.op,tr.araddr, tr.rdata,tr.rresp);
        mbxms.put(tr);
      end
    end
  endtask
endclass

class scoreboard;
  transaction tr,trd;
  event sconext;
  
  mailbox #(transaction) mbxms;
  
  bit [31:0] temp;
  bit [31:0] data[128] ='{default:0};
  
  function new(mailbox #(transaction) mbxms);
    this.mbxms=mbxms;
  endfunction
  
  task run();
    forever begin
      mbxms.get(tr);
      if(tr.op) begin
        $display("[SCO] : OP = %0d, awaddr = %0d, wdata = %0d, wresp = =%0d",tr.op,tr.awaddr,tr.wdata,tr.wresp);
        if(tr.wresp==3)
          $display("[SCO] : Decoder Error");
        else begin
          data[tr.awaddr]=tr.wdata;
          $display("[SCO] : Data Stored Addr = %0d and Data = %0d", tr.awaddr,tr.wdata);
        end
      end
      else begin 
        $display("[SCO] : OP %0d, araddr = %0d, rdata = %0d, rresp = %0d", tr.op, tr.araddr, tr.rdata, tr.rresp);
        temp = data[tr.araddr];
        if(tr.rresp==3)
          $display("[SCO] : Decoder Error");
        else if(tr.rresp==0 && tr.rdata==temp)
          $display("[SCO] : Data Matched");
        else $display("[SCO] : Data Mismatched");
      end
      $display("-------------------------------------------------------");
     ->sconext;
    end
  endtask
endclass

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
 //event nextgd;
  event nextgm;
  
  mailbox #(transaction) mbxgd,mbxms,mbxdm;
  
  virtual axi_if vif;
  
  function new(virtual axi_if vif);
    mbxgd = new();
    mbxms = new();
    mbxdm = new();
    
    gen = new(mbxgd);
    drv = new(mbxgd,mbxdm);
    mon = new(mbxms,mbxdm);
    sco = new(mbxms);
    
    this.vif=vif;
    drv.vif=vif;
    mon.vif=vif;
    
    gen.sconext=nextgm;
    sco.sconext=nextgm;
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass

module tb;
  axi_if vif();
  environment env;
  axilite_slave dut(vif.clk,vif.resetn,vif.awvalid,vif.awaddr,vif.awready,vif.wvalid,vif.wdata,vif.wready,vif.bready,vif.bvalid,vif.wresp,vif.arvalid,vif.araddr,vif.arready,vif.rready,vif.rvalid,vif.rresp,vif.rdata);
  
  initial begin
    vif.clk<=0;
  end
  always #10 vif.clk=~vif.clk;
  
  initial begin
    env=new(vif);
    env.gen.count=10;
    env.run();
  end
  
  initial  begin
    $dumpfile("dumpvcd");
    $dumpvars;
  end
endmodule
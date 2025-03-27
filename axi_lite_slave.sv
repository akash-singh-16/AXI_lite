`timescale 1ns / 1ps

module axilite_slave(
  input s_axi_aclk, s_axi_aresetn, s_axi_awvalid,
  input [31:0] s_axi_awaddr,
  output reg s_axi_awready,
  
  input s_axi_wvalid,
  input [31:0] s_axi_wdata,
  output reg s_axi_wready,
  
  input s_axi_bready,
  output reg s_axi_bvalid,
  output reg[1:0] s_axi_bresp,
  
  input s_axi_arvalid,
  input [31:0] s_axi_araddr,
  output reg s_axi_arready,
  
  input s_axi_rready,
  output reg s_axi_rvalid,
  output reg [1:0] s_axi_rresp,
  output reg [31:0] s_axi_rdata
);
  
  localparam idle=0,send_waddr_ack=1, send_raddr_ack=2, send_wdata_ack=3, update_mem =4, send_wr_err=5, send_wr_resp=6, gen_data=7, send_rd_err=8, send_rdata=9;
  
  reg[3:0] state=idle;
  reg[3:0] next_state=idle;
  reg[1:0] count =0;
  reg [31:0] waddr, raddr, wdata, rdata;
  
  reg[31:0] mem[128];
  
  always @(posedge s_axi_aclk) begin
    if(!s_axi_aresetn) begin
      state<=idle;
      for(int i=0;i<128;i++) begin
        mem[i]=0;
      end
      s_axi_awready<=0;
      s_axi_wready<=0;
      s_axi_bvalid<=0;
      s_axi_bresp<=0;
      s_axi_arready<=0;
      s_axi_rvalid<=0;
      s_axi_rdata<=0;
      s_axi_rresp<=0;
      waddr<=0;
      raddr<=0;
      wdata<=0;
      rdata<=0;
    end
    else begin
      case(state)
        idle: begin
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            s_axi_bvalid  <= 0;
            s_axi_bresp   <= 0;
            s_axi_arready <= 0;
            s_axi_rvalid  <= 0;
            s_axi_rdata   <= 0;
            s_axi_rresp   <= 0;
            waddr         <= 0;
            raddr         <= 0;
            wdata         <= 0;
            rdata         <= 0;
            count         <= 0;
            s_axi_rvalid  <= 0; 
          
          if(s_axi_awvalid==1) begin
            state<= send_waddr_ack;
            waddr<=s_axi_awaddr;
            s_axi_awready<=1;
          end
            else if(s_axi_arvalid==1) begin
              state<= send_raddr_ack;
              raddr<=s_axi_araddr;
              s_axi_arready<=1;
            end
            else begin
              state<=idle;
            end
        end
          send_waddr_ack: begin
            s_axi_awready <=0;
            if(s_axi_wvalid) begin
              wdata<=s_axi_wdata;
              s_axi_wready<=1;
              state<=send_wdata_ack;
            end
            else begin
              state<=send_waddr_ack;
            end
          end         
          send_wdata_ack : begin
            s_axi_wready<=0;
            if(waddr<128) begin
              state<=update_mem;
              mem[waddr]<=wdata;
            end
            else begin
              state<=send_wr_err;
              s_axi_bresp<=2'b11;
              s_axi_bvalid<=1'b1;
            end
          end
          update_mem: begin
            mem[waddr]<=wdata;
            state<=send_wr_resp;
          end
          send_wr_resp: begin
            s_axi_bresp<=2'b00;
            s_axi_bvalid<=1'b1;
            if(s_axi_bready) state<=idle;         
            else state<=send_wr_resp;
           end
          send_wr_err: begin
            if(s_axi_bready) state<=idle;
            else state<=send_wr_err;
          end
          send_raddr_ack: begin
            s_axi_arready<=0;
            if(raddr<128) state<=gen_data;
            else begin
              s_axi_rvalid<=1;
              state<=send_rd_err;
              s_axi_rdata<=0;
              s_axi_rresp<=2'b11;
            end
          end
          gen_data: begin
            if(count<2) begin
              rdata<=mem[raddr];
              state<=gen_data;
              count<=count+1;
            end
            else begin
              s_axi_rvalid<=1;
              s_axi_rdata<=rdata;
              s_axi_rresp<=2'b00;
              
              if(s_axi_rready) state<=idle;
              else state<=gen_data;
            end
          end
          send_rd_err: begin
            if(s_axi_rready) state<=idle;
            else state<=send_rd_err;
          end
          default: state<=idle;
          endcase
     end
  end      
endmodule

interface axi_if;
  logic clk,resetn;
  logic awvalid,awready;
  logic arvalid,arready;
  logic wvalid,wready;
  logic bready,bvalid;
  logic rvalid,rready;
  logic [31:0] awaddr, araddr, wdata, rdata;
  logic [1:0] wresp,rresp;
endinterface
        
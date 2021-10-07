`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    output [`EXE_TRACE_BACK  - 1:0]     exe_back_djk  ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire [14:0] es_alu_op     ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [31:0] es_imm        ;
wire [31:0] es_rj_value   ;
wire [31:0] es_rkd_value  ;
wire [31:0] es_pc         ;
wire [3:0]  es_div        ;
wire        en_div        ;
wire        es_res_from_mem;

assign {en_div         ,
        es_div         ,
        es_alu_op      ,  //149:138
        es_res_from_mem,  //137:137
        es_src1_is_pc  ,  //136:136
        es_src2_is_imm ,  //135:135
        es_gr_we       ,  //134:134
        es_mem_we      ,  //133:133
        es_dest        ,  //132:128
        es_imm         ,  //127:96
        es_rj_value    ,  //95 :64
        es_rkd_value   ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

assign exe_back_djk = {es_res_from_mem&&es_valid,
                       es_gr_we&&es_valid,
                       es_dest,
                       res
                      };
wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;

//assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       res  ,  //63:32
                       es_pc             //31:0
                      };

assign es_ready_go    = ~((en_div&&(es_div[0]||es_div[1])&& m_axis_dout_tvalid!=1'b1)||(en_div&&(es_div[2]||es_div[3])&& m_axis_dout_tvalid_u!=1'b1));
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin     
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin 
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_pc  ? es_pc[31:0] : 
                                      es_rj_value;
                                      
assign es_alu_src2 = es_src2_is_imm ? es_imm : 
                                      es_rkd_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),//change
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result)
    );

wire s_axis_divisor_tvalid;
wire s_axis_dividend_tvalid;
wire s_axis_divisor_tvalid_u;
wire s_axis_dividend_tvalid_u;
wire [63:0] res_from_div0;
wire [63:0] res_from_div1;
wire [31:0] res_div;
wire [31:0] res;
wire [63:0] m_axis_dout_tdata;
wire [63:0] m_axis_dout_tdata_u;

reg divisor_ok;
reg dividend_ok;
reg divisor_ok_u;
reg dividend_ok_u;

always @(posedge clk) begin
    if(reset)
        divisor_ok <=1'b0;
    else if(s_axis_divisor_tready==1'b1&&s_axis_divisor_tvalid==1'b1)
        divisor_ok <=1'b1;
    else if (en_div&&(es_div[0]||es_div[1]))
        divisor_ok <= divisor_ok;
    else 
        divisor_ok <= 1'b0;
end

always @(posedge clk) begin
    if(reset)
        dividend_ok <=1'b0;
    else if(s_axis_dividend_tready==1'b1&&s_axis_dividend_tvalid==1'b1)
        dividend_ok <=1'b1;
    else if (en_div&&(es_div[0]||es_div[1]))
        dividend_ok <= dividend_ok;
    else 
        dividend_ok <= 1'b0;
end

always @(posedge clk) begin
    if(reset)
        divisor_ok_u <=1'b0;
    else if(s_axis_divisor_tready_u==1'b1&&s_axis_divisor_tvalid_u==1'b1)
        divisor_ok_u <=1'b1;
   else if (en_div&&(es_div[2]||es_div[3]))
        divisor_ok_u <= divisor_ok_u;
    else 
        divisor_ok_u <= 1'b0;
end

always @(posedge clk) begin
    if(reset)
        dividend_ok_u <=1'b0;
    else if(s_axis_dividend_tready_u==1'b1&&s_axis_dividend_tvalid_u==1'b1)
        dividend_ok_u <=1'b1;
    else if (en_div&&(es_div[2]||es_div[3]))
        dividend_ok_u <= dividend_ok_u;
    else 
        dividend_ok_u <= 1'b0;
end
assign s_axis_dividend_tvalid = en_div && (es_div[0]||es_div[1]) && dividend_ok == 1'b0 ;
assign s_axis_divisor_tvalid  = en_div && (es_div[0]||es_div[1]) && divisor_ok == 1'b0;
assign s_axis_dividend_tvalid_u = en_div && (es_div[2]||es_div[3]) && dividend_ok_u == 1'b0;
assign s_axis_divisor_tvalid_u = en_div && (es_div[2]||es_div[3]) && divisor_ok_u == 1'b0;
assign res_from_div0 = m_axis_dout_tvalid ? m_axis_dout_tdata:
                                            64'b0;
assign res_from_div1 = m_axis_dout_tvalid_u ? m_axis_dout_tdata_u:
                                              64'b0;
assign res_div       = ({32{es_div[0]    }} & res_from_div0[63:32])
                     | ({32{es_div[1]    }} & res_from_div0[31:0])
                     | ({32{es_div[2]    }} & res_from_div1[63:32])
                     | ({32{es_div[3]    }} & res_from_div1[31:0]);
assign res = en_div     ? res_div:
                    es_alu_result;
div_gen_0 div_gen_0 (
  .aclk(clk),                                      // input wire aclk
  .s_axis_divisor_tvalid(s_axis_divisor_tvalid),    // input wire s_axis_divisor_tvalid 
  .s_axis_divisor_tready(s_axis_divisor_tready),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata(es_alu_src2),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(s_axis_dividend_tvalid),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tready(s_axis_dividend_tready),  // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata(es_alu_src1),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_axis_dout_tdata)            // output wire [63 : 0] m_axis_dout_tdata
);
div_gen_1 div_gen_1 (
  .aclk(clk),                                      // input wire aclk
  .s_axis_divisor_tvalid(s_axis_divisor_tvalid_u),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tready(s_axis_divisor_tready_u),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata(es_alu_src2),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(s_axis_dividend_tvalid_u),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tready(s_axis_dividend_tready_u),  // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata(es_alu_src1),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid_u),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_axis_dout_tdata_u)            // output wire [63 : 0] m_axis_dout_tdata
);
assign data_sram_en    = (es_res_from_mem || es_mem_we) && es_valid;//visit mem....en/wen
assign data_sram_wen   = es_mem_we ? 4'hf : 4'h0;
assign data_sram_addr  = res;
assign data_sram_wdata = es_rkd_value;

endmodule

`include "mycpu.h"

module wb_stage(
    output [13:0]  csr_num_wb   ,
    output [31:0]  ertn_era_wb,
    output [31:0]  eentry_wb,
    output [31:0]  csr_wvalue_wb   ,
    output [31:0]  csr_wmask_wb,
    output csr_we_wb,
    output ertn_flush_wb,
    output wb_ex,
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //to DATA_RISK_BUS
    output [4 :0] wb_waddr        ,
    //to CSR
    output [31:0] wb_vaddr,
    output [31:0] wb_pc,
    output [5:0]  wb_ecode,
    output [8:0]  wb_esubcode,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
//wire [13:0]  csr_num_wb   
//wire [31:0]  csr_wvalue_wb
//wire [31:0]  csr_wmask_wb
//wire csr_we_wb
wire csr_re_wb;
wire exec_ADEF;
wire exec_INE;
wire exec_ALE;
wire exec_SYS;
wire exec_BRK;
reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
assign wb_pc = ws_pc;
assign wb_ecode = 
                {6{exec_SYS }} & `ECODE_SYS |            
                {6{exec_BRK }} & `ECODE_BRK |
                {6{exec_ADEF}} & `ECODE_ADE |
                {6{exec_INE }} & `ECODE_INE |
                {6{exec_ALE }} & `ECODE_ALE ;         
assign wb_ex = (wb_ecode != 6'b0);

assign wb_esubcode = {8{exec_ADEF}} & `ESUBCODE_ADEF;
assign {
        csr_wvalue_wb,  //219:188
        csr_rvalue_wb,  //187:156
        ertn_flush_wb,  //155
        csr_wmask_wb,   //154:123
        csr_re_wb,      //122
        csr_we_wb,      //121
        csr_num_mem,    //120:107
        wb_vaddr,       //106:75
        exec_SYS,       //74
        exec_BRK,       //73
        exec_ADEF,      //72
        exec_INE,       //71
        exec_ALE,       //70
        ws_gr_we       ,  //69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;
assign ertn_era_wb = csr_rvalue_wb;
assign eentry_wb = csr_rvalue_wb;

assign wb_waddr = ws_dest & {5{ws_gr_we}} & {5{ws_valid}};
wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end
    if (reset) begin    
        ms_to_ws_bus_r <= 70'b0;
    end
    else if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we&&ws_valid;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule

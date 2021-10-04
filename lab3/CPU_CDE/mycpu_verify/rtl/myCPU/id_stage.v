`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1 :0] fs_to_ds_bus  ,
    //input [`TRACE_BACK - 1:0]      ws_back_djk  ,
    input [`TRACE_BACK - 1:0]      mem_back_djk  ,
    input [`EXE_TRACE_BACK - 1:0]      exe_back_djk  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  
);

reg         ds_valid   ;
wire        ds_ready_go;

reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {ds_inst,
        ds_pc} = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire [31:0] br_target;

wire [11:0] alu_op;
wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] ds_imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
  
wire        inst_add_w; 
wire        inst_sub_w;  
wire        inst_slt;    
wire        inst_sltu;   
wire        inst_nor;    
wire        inst_and;    
wire        inst_or;     
wire        inst_xor;    
wire        inst_slli_w;  
wire        inst_srli_w;  
wire        inst_srai_w;  
wire        inst_addi_w; 
wire        inst_ld_w;  
wire        inst_st_w;   
wire        inst_jirl;   
wire        inst_b;      
wire        inst_bl;     
wire        inst_beq;    
wire        inst_bne;    
wire        inst_lu12i_w;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;  
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rj_eq_rd;
assign br_bus       = {br_taken,br_target};
assign ds_to_es_bus = 
                      {alu_op      ,  //149:138
                       load_op     ,  //137:137
                       src1_is_pc  ,  //136:136
                       src2_is_imm ,  //135:135
                       gr_we       ,  //134:134
                       mem_we      ,  //133:133
                       dest        ,  //132:128
                       ds_imm      ,  //127:96
                       rj_value    ,  //95 :64
                       rkd_value   ,  //63 :32
                       ds_pc          //31 :0
                      };

assign ds_ready_go    = ~(exe_back_djk[38]&&(exe_back_djk[36:32]==rf_raddr1||exe_back_djk[36:32]==rf_raddr2));
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin 
    if (reset) begin     
        ds_valid <= 1'b0;
    end
    else if(br_taken&&ds_ready_go)
        ds_valid <= 1'b0;
    else if (ds_allowin) begin 
        ds_valid <= fs_to_ds_valid;
    end//change

    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];//rd rj rk 
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];//rd rj
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];//rd :1 
assign inst_bl     = op_31_26_d[6'h15];//rd :1
assign inst_beq    = op_31_26_d[6'h16];//rd rj
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];//rd

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w 
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;
assign load_op    = inst_ld_w;//change

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;//pc+4




assign ds_imm = src2_is_4 ? 32'h4               :
		need_si20 ? {12'b0,i20[4:0],i20[19:5]} :  //i20[16:5]==i12[11:0]
  /*need_ui5 || need_si12*/ {{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} : 
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};//jirl offset process

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;//

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w | 
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;


assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

/*wire        raw;      //read after write
wire        raw_rk;
wire        raw_rj;
wire        raw_rd;*/
wire        read_rj;
wire        read_rk;
wire        read_rd;
wire        read_rkd;

assign      read_rk = inst_add_w||inst_sub_w||inst_slt||inst_sltu||inst_nor||inst_and||inst_xor||inst_or;
assign      read_rj = read_rk || inst_slli_w ||inst_srai_w ||inst_srli_w || inst_addi_w ||inst_ld_w ||inst_st_w ||inst_jirl||inst_beq||inst_bne;
assign      read_rd = inst_beq || inst_bne ||inst_st_w ||inst_ld_w ;
assign      read_rkd= read_rk || read_rd;
/*assign raw_rk       = (ws_to_rf_bus[37]&&ws_to_rf_bus[36:32]==rk)||
                      (mem_back_djk[37]&&mem_back_djk[36:32]==rk)||
                      (exe_back_djk[37]&&exe_back_djk[36:32]==rk)
                      ;
assign raw_rj       = (ws_to_rf_bus[37]&&ws_to_rf_bus[36:32]==rj)||
                      (mem_back_djk[37]&&mem_back_djk[36:32]==rj)||
                      (exe_back_djk[37]&&exe_back_djk[36:32]==rj)
                      ;
assign raw_rd       = (ws_to_rf_bus[37]&&ws_to_rf_bus[36:32]==rd)||
                      (mem_back_djk[37]&&mem_back_djk[36:32]==rd)||
                      (exe_back_djk[37]&&exe_back_djk[36:32]==rd)
                      ;
assign raw          = (raw_rk&&read_rk&&rk!=5'b0)||(raw_rj&&read_rj&&rj!=5'b0)||(raw_rd&&read_rd&&rd!=5'b0);*/
assign rj_value     = (exe_back_djk[37]&&exe_back_djk[36:32]==rj&&read_rj) ? exe_back_djk[31:0]:
                      (mem_back_djk[37]&&mem_back_djk[36:32]==rj&&read_rj) ? mem_back_djk[31:0]:
                      (ws_to_rf_bus[37]&&ws_to_rf_bus[36:32]==rj&&read_rj) ? ws_to_rf_bus[31:0]:
                      rf_rdata1;
assign rkd_value    = (exe_back_djk[37]&&exe_back_djk[36:32]==rf_raddr2&&read_rkd) ? exe_back_djk[31:0]:
                      (mem_back_djk[37]&&mem_back_djk[36:32]==rf_raddr2&&read_rkd) ? mem_back_djk[31:0]:
                      (ws_to_rf_bus[37]&&ws_to_rf_bus[36:32]==rf_raddr2&&read_rkd) ? ws_to_rf_bus[31:0]:
                      rf_rdata2;
/*assign rj_value  = rf_rdata1; 
assign rkd_value = rf_rdata2;*/

assign rj_eq_rd = (rj_value == rkd_value);


assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
) && ds_valid; 
//assign ds_pc = ds_pc - 32'd4;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (ds_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

endmodule

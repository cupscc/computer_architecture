`include "mycpu.h"

module id_stage(
    //to CSR
    output [13:0] csr_num_id    ,
    input  [13:0] csr_num_wb    ,   
    input  [13:0] csr_num_exe   ,
    input  [13:0] csr_num_mem   ,
    input  [31:0] csr_rvalue    ,
    output csr_re_id,
    input  clear,

    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    input  [`DATA_RISK_BUS   -1:0] DATA_RISK_BUS ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  
);
wire [31:0] csr_wmask_id;
wire csr_we_id;
wire exec_ADEF;
wire exec_INE;
wire exec_SYS;
wire exec_BRK;
//DATA_RISK_BUS
wire [4:0]  exe_waddr;
wire [4:0]  mem_waddr;
wire [4:0]  wb_waddr ;
wire        exe_mem_load;
wire [4:0]  exe_mem_waddr;
wire [31:0] exe_alu_result;
wire [31:0] mem_mem_result;
wire [31:0] debug_wb_rf_wdata;
assign exe_waddr         = DATA_RISK_BUS[116:112];
assign mem_waddr         = DATA_RISK_BUS[111:107];
assign wb_waddr          = DATA_RISK_BUS[106:102];
assign exe_mem_load      = DATA_RISK_BUS[101];
assign exe_mem_waddr     = DATA_RISK_BUS[100: 96];
assign exe_alu_result    = DATA_RISK_BUS[95 : 64];
assign mem_mem_result    = DATA_RISK_BUS[63 : 32];
assign debug_wb_rf_wdata = DATA_RISK_BUS[31 :  0];

reg         ds_valid   ;
wire        ds_ready_go;

reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

reg [31:0] inner_reg [31:0];
wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
assign {exec_ADEF,
        ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;
       
wire        br_taken;
wire [31:0] br_target;

wire [12:0] alu_op;
wire [2 :0] mul_div;
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
wire [31:0] rd_value;
wire [31:0] rk_value;
wire [31:0] rkd_value;
wire [31:0] ds_imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] op_14_10;
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
wire [31:0] op_14_10_d;
//instructions 
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
    wire        inst_ld_b;  
    wire        inst_ld_h;  
    wire        inst_ld_bu;  
    wire        inst_ld_hu;  
    wire        inst_st_w;   
    wire        inst_jirl;   
    wire        inst_b;      
    wire        inst_bl;     
    wire        inst_beq;    
    wire        inst_bne;    
    wire        inst_blt;
    wire        inst_bltu;
    wire        inst_bge;
    wire        inst_bgeu;
    wire        inst_lu12i_w;
    wire        inst_sll   ;
    wire        inst_srl   ;
    wire        inst_sra   ;
    wire        inst_slti  ;
    wire        inst_sltui ;
    wire        inst_addi_w;
    wire        inst_andi_w;
    wire        inst_ori_w ;
    wire        inst_xori_w;
    wire        inst_mul_w  ;
    wire        inst_mulh_w ; 
    wire        inst_mulh_wu;
    wire        inst_div_w  ; 
    wire        inst_mod_w  ;
    wire        inst_div_wu ;
    wire        inst_mod_wu ;
    wire        inst_syscall;
    wire        inst_break;
    wire        inst_csrrd;
    wire        inst_csrwr;
    wire        inst_csrxchg;
    wire        inst_ertn;
assign csr_re_id = inst_csrrd  | inst_csrwr | inst_csrxchg | inst_ertn; 
assign csr_we_id = inst_csrwr  | inst_csrxchg;
assign csr_wmask_id =   {32{inst_csrwr}}    & 32'hffffffff |
                        {32{inst_csrxchg}}  & rj_value;
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

assign br_bus = {br_taken,br_target};

assign load_op = inst_ld_w | inst_ld_b  | inst_ld_bu    | inst_ld_h |inst_ld_hu;
reg id_cancel;
wire [2:0] ld_code = {3{inst_ld_w} }   & 3'b000       |
                     {3{inst_ld_b} }   & 3'b001       |               
                     {3{inst_ld_bu}}   & 3'b010       |  
                     {3{inst_ld_h} }   & 3'b011       |
                     {3{inst_ld_hu}}   & 3'b100       ;
wire [1:0] st_code = {2{inst_st  }}    & 2'b00        |
                     {2{inst_st_b}}    & 2'b01        |  
                     {2{inst_st_h}}    & 2'b10        ;
wire ertn_flush_id = inst_ertn;
assign ds_to_es_bus = {
                       ertn_flush_id,//243
                       csr_wmask_id,//242:211
                       csr_rvalue,  //210:179
                       csr_re_id,   //178
                       csr_we_id,   //177
                       csr_num_id,//176:163
                       exec_SYS, //162
                       exec_BRK, //161
                       exec_ADEF,//160
                       exec_INE ,//159
                       ld_code  ,//158:156
                       st_code  ,//155:154
                       mul_div     ,  //153:151
                       alu_op      ,  //150:138
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
wire data_risk_delay;
wire csr_risk_delay;
assign ds_ready_go    = ~(exe_mem_load && data_risk_delay || csr_risk_delay) &&  1'b1;
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = !clear && ~id_cancel && ds_valid && ds_ready_go;

always @(posedge clk) begin
    if (reset) begin     
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin 
        ds_valid <= fs_to_ds_valid;
    end
    if (reset) begin
        fs_to_ds_bus_r <= 300'b0;
    end
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end
wire [13:0] csr_era = `CSR_ERA;
wire [13:0] csr_eentry = `CSR_EENTRY;
assign csr_num_id  = {14{inst_ertn}}    & csr_era      |
                    {14{inst_syscall}}  & csr_eentry   |
                    {14{!inst_ertn && !inst_syscall}}   & ds_inst[23:10];

assign op_31_26 = ds_inst[31:26];
assign op_25_24 = ds_inst[25:24];
assign op_25_22 = ds_inst[25:22];
assign op_21_20 = ds_inst[21:20];
assign op_19_15 = ds_inst[19:15];
assign op_14_10 = ds_inst[14:10];

assign rd = ds_inst[ 4: 0];
assign rj = ds_inst[ 9: 5];
assign rk = ds_inst[14:10];

assign i12 = ds_inst[21:10];
assign i20 = ds_inst[24: 5];
assign i16 = ds_inst[25:10];
assign i26 = {ds_inst[ 9: 0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));
decoder_5_32 u_dec4(.in(op_14_10 ), .out(op_14_10_d ));
//inst judge
assign inst_add_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
    assign inst_sub_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
    assign inst_nor   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    assign inst_and   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    assign inst_or    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    assign inst_xor   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
    assign inst_slt   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
    assign inst_sltu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
    assign inst_sll = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
    assign inst_srl = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
    assign inst_sra = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
    assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
    assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
    assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
    assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
    assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
    assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
    assign inst_andi_w = op_31_26_d[6'h00] & op_25_22_d[4'hd];
    assign inst_ori_w  = op_31_26_d[6'h00] & op_25_22_d[4'he];
    assign inst_xori_w = op_31_26_d[6'h00] & op_25_22_d[4'hf];
    assign inst_mul_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
    assign inst_mulh_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
    assign inst_mulh_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
    assign inst_div_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
    assign inst_mod_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
    assign inst_div_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
    assign inst_mod_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
    //priviledge
    assign inst_syscall = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
    assign inst_break   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
    assign inst_ertn    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0d];
    assign inst_csrrd   = op_31_26_d[6'h01] & (op_25_24 == 2'b0) & (rj == 5'b0);
    assign inst_csrwr   = op_31_26_d[6'h01] & (op_25_24 == 2'b0) & (rj == 5'b1);
    assign inst_csrxchg = op_31_26_d[6'h01] & (op_25_24 == 2'b0) & (rj != 5'b1 && rj != 5'b0);
    //ld
    assign inst_ld_w = op_31_26_d[6'h0a]  & op_25_22_d[4'h2];
    assign inst_ld_b = op_31_26_d[6'h0a]  & op_25_22_d[4'h0];
    assign inst_ld_h = op_31_26_d[6'h0a]  & op_25_22_d[4'h1];
    assign inst_ld_bu = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
    assign inst_ld_hu = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
    //st
    assign inst_st_b = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
    assign inst_st_h = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
    assign inst_st_w = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_jirl = op_31_26_d[6'h13];
    assign inst_b    = op_31_26_d[6'h14];
    //b_type
    assign inst_bl   = op_31_26_d[6'h15];
    assign inst_beq  = op_31_26_d[6'h16];
    assign inst_bne  = op_31_26_d[6'h17];
    assign inst_blt  = op_31_26_d[6'h18];
    assign inst_bge  = op_31_26_d[6'h19];
    assign inst_bltu = op_31_26_d[6'h1a];
    assign inst_bgeu = op_31_26_d[6'h1b];
    assign inst_lu12i_w = op_31_26_d[6'h05] & ~ds_inst[25];
    assign inst_pcaddui = op_31_26_d[6'h07] & ~ds_inst[25];

assign exec_SYS = inst_syscall;
assign exec_BRK = inst_break;
assign exec_INE = 
           !(inst_add_w | inst_sub_w| inst_nor  | inst_and      |
             inst_or    | inst_xor  | inst_slt  | inst_sltu     |
             inst_sll   | inst_srl  | inst_sra  | inst_slli_w   |   
             inst_srli_w  | inst_srai_w | inst_slti     | inst_sltui   |
             inst_addi_w  | inst_andi_w | inst_ori_w    | inst_xori_w  |
             inst_mul_w | inst_mulh_w   | inst_mulh_wu  | inst_div_w   |
             inst_mod_w | inst_div_wu   | inst_mod_wu   | inst_syscall |
             inst_break | inst_ertn     | inst_csrrd    | inst_csrwr   |
             inst_csrxchg   | inst_ld   | inst_st       | inst_jirl    |
             inst_b_type    | inst_bl   | inst_pcaddui  | inst_lu12i_w); 

assign mul_div = {3{inst_mul_w  }}    & 3'd1 |
                 {3{inst_mulh_w }}    & 3'd2 |
                 {3{inst_mulh_wu}}    & 3'd3 |
                 {3{inst_div_w  }}    & 3'd4 |
                 {3{inst_mod_w  }}    & 3'd5 |
                 {3{inst_div_wu }}    & 3'd6 |
                 {3{inst_mod_wu }}    & 3'd7 ;

wire inst_ld = inst_ld_w  | inst_ld_b | inst_ld_bu  | inst_ld_h | inst_ld_hu ;
wire inst_st = inst_st_w  | inst_st_b | inst_st_h;
assign alu_op[ 0] = inst_add_w  | inst_addi_w | inst_ld | inst_st | inst_jirl | inst_bl |inst_pcaddui;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt    | inst_slti;
assign alu_op[ 3] = inst_sltu   | inst_sltui;
assign alu_op[ 4] = inst_and    | inst_andi_w;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or     | inst_ori_w;
assign alu_op[ 7] = inst_xor    | inst_xori_w;
assign alu_op[ 8] = inst_slli_w | inst_sll;
assign alu_op[ 9] = inst_srli_w | inst_srl;
assign alu_op[10] = inst_srai_w | inst_sra;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_pcaddui;


assign need_ui5  = inst_slli_w    | inst_srli_w   | inst_srai_w   ;
assign need_si12 = inst_addi_w    | inst_ld       | inst_st       | inst_slti     | inst_sltui    | need_ui5      ;
assign need_si16 = inst_jirl      | inst_beq      | inst_bne      | inst_blt      | inst_bltu     | inst_bge      | inst_bgeu;
assign need_si20 = inst_lu12i_w   | inst_pcaddui  ;
assign need_si26 = inst_b | inst_bl;
assign need_0_12 = inst_andi_w    | inst_ori_w    |inst_xori_w;
assign src2_is_4 = inst_jirl | inst_bl;



assign ds_imm = {32{src2_is_4}} & 32'h4                         |
                {32{need_si20}} & {12'b0,i20[4:0],i20[19:5]}    |
                {32{need_si12}} & {{20{i12[11]}}, i12[11:0]}    |
                {32{need_0_12}} & {20'b0, i12[11:0]};
		//need_si20 ? {12'b0,i20[4:0],i20[19:5]} :  //i20[16:5]==i12[11:0]
  /*need_ui5 || need_si12*/ //{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_b_type| inst_st | inst_csrwr;

assign src1_is_pc = inst_jirl    | inst_bl  | inst_pcaddui;

assign src2_is_imm = inst_slli_w |
                       inst_slti   |
                       inst_sltui  |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_andi_w |
                       inst_ori_w  |
                       inst_xori_w |
                       inst_ld   |
                       inst_st   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_pcaddui;
wire inst_b_type = inst_beq | inst_bne | inst_b | inst_blt | inst_bltu | inst_bge | inst_bgeu;

assign res_from_mem = inst_ld;
assign dst_is_r1    = inst_bl;
assign gr_we        = ~inst_st & ~inst_b_type & ~inst_ertn;
assign mem_we       = inst_st;
assign dest         = dst_is_r1 ? 5'd1 : rd;

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
wire csr_risk_exe  = (csr_num_id == csr_num_exe);
wire csr_risk_mem  = (csr_num_id == csr_num_mem);
wire csr_risk_wb   = (csr_num_id == csr_num_wb );
assign csr_risk_delay =   csr_re_id & ( csr_risk_exe | csr_risk_mem  | csr_risk_wb);   //CSR写后读可能发生的冲突用阻塞解Jue
                        
                        
assign data_risk_delay = (rj == exe_mem_waddr) & (rj != 5'b0) & (|exe_mem_waddr) ||
                        (rd == exe_mem_waddr) & (rd != 5'b0) & (|exe_mem_waddr) ||
                        (rk == exe_mem_waddr) & (rk != 5'b0) & (|exe_mem_waddr) ;
wire data_risk_rj_exe = (rj == exe_waddr) & (rj != 5'b0) & (|exe_waddr);
wire data_risk_rj_mem = (rj == mem_waddr) & (rj != 5'b0) & (|mem_waddr);
wire data_risk_rj_wb  = (rj == wb_waddr ) & (rj != 5'b0) & (|wb_waddr );

wire data_risk_rd_exe = (rd == exe_waddr) & (rd != 5'b0) & (|exe_waddr) ;
wire data_risk_rd_mem = (rd == mem_waddr) & (rd != 5'b0) & (|mem_waddr) ;
wire data_risk_rd_wb  = (rd == wb_waddr ) & (rd != 5'b0) & (|wb_waddr ) ;

wire data_risk_rk_exe = (rk == exe_waddr) & (rk != 5'b0) & (|exe_waddr) ;
wire data_risk_rk_mem = (rk == mem_waddr) & (rk != 5'b0) & (|mem_waddr) ;
wire data_risk_rk_wb  = (rk == wb_waddr ) & (rk != 5'b0) & (|wb_waddr ) ;

wire data_risk_exe = data_risk_rj_exe || data_risk_rd_exe || data_risk_rk_exe;
wire data_risk_mem = data_risk_rj_mem || data_risk_rd_mem || data_risk_rk_mem;
wire data_risk_wb  = data_risk_rj_wb  || data_risk_rd_wb  || data_risk_rk_wb ;


assign rj_value = data_risk_rj_exe ? exe_alu_result :
                (   data_risk_rj_mem ? mem_mem_result :
                (   data_risk_rj_wb  ? debug_wb_rf_wdata :
                                rf_rdata1)); 
assign rd_value = data_risk_rd_exe ? exe_alu_result :
                (   data_risk_rd_mem ? mem_mem_result :
                (   data_risk_rd_wb  ? debug_wb_rf_wdata :
                                rf_rdata2)); 
assign rk_value = data_risk_rk_exe ? exe_alu_result :
                (   data_risk_rk_mem ? mem_mem_result :
                (   data_risk_rk_wb  ? debug_wb_rf_wdata :
                                rf_rdata2)); 

assign rkd_value = src_reg_is_rd ? rd_value :rk_value;

assign rj_eq_rd  = (rj_value == rkd_value);
assign rj_lt_rd  = (rj_value == rkd_value);
assign rj_ge_rd  = (rj_value == rkd_value);
assign rj_ltu_rd = (rj_value == rkd_value);
assign rj_geu_rd = (rj_value == rkd_value);

wire b_type_jump;

assign br_taken = ~id_cancel &&
                (   inst_beq  &&  rj_eq_rd     ||
                    inst_blt  &&  b_type_jump  ||
                    inst_bge  &&  b_type_jump  ||
                    inst_bltu &&  b_type_jump  ||
                    inst_bgeu &&  b_type_jump  ||
                    inst_bne  && !rj_eq_rd     || 
                    inst_jirl                  || 
                    inst_bl                    || 
                    inst_b
                  ) && ds_valid; 
assign br_target = (inst_b_type  | inst_bl ) ? (ds_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

always @(posedge clk) begin
    if(reset)begin
        id_cancel <= 1'b0;
    end
    else begin
        if(br_taken && ds_ready_go)begin
            id_cancel <= 1'b1;
        end
        else if(ds_ready_go) begin
            id_cancel <= 1'b0;
        end
    end
end
wire [1:0] type = {2{inst_blt}}  & 2'b00    |
                  {2{inst_bge}}  & 2'b01    |
                  {2{inst_bltu}} & 2'b10    |
                  {2{inst_bgeu}} & 2'b11;

B_type_Jump B_type(
    .type(type),
    .A(rj_value),
    .B(rkd_value),
    .jump(b_type_jump)
);

endmodule

module B_type_Jump(
    input [1:0] type,
    input [31:0] A,
    input [31:0] B,
    output jump
);
    wire op_lt  = type == 2'b00;
    wire op_ge  = type == 2'b01;
    wire op_ltu = type == 2'b10;
    wire op_geu = type == 2'b11;
    
wire [31:0] adder_a = A;
wire [31:0] adder_b = ~B;
wire [31:0] adder_result;
wire adder_cin =  1'b1;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;
wire   lt_result                  = A[31] & ~B[31]  ||
                 (A[31] ~^ B[31]) & adder_result[31];
wire ltu_result = ~adder_cout;
assign jump =   op_lt   &  lt_result    ||
                op_ge   & ~lt_result    ||
                op_ltu  &  ltu_result   ||
                op_geu  & !ltu_result;

endmodule

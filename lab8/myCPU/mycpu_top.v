module mycpu_top(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_en,
    output [ 3:0] inst_sram_wen,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_en,
    output [ 3:0] data_sram_wen,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
//top文件整体比较混乱，主要在于信号名和信号管理，周三晚上搞一下，预期把top中的信号与其他的信号分割开
reg         reset;
always @(posedge clk) reset <= ~resetn; 

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [`DATA_RISK_BUS   -1:0] DATA_RISK_BUS;

wire [4:0]  exe_waddr;
wire [4:0]  mem_waddr;
wire [4:0]  wb_waddr;
wire        exe_mem_load;
wire [4:0]  exe_mem_waddr;
wire [31:0] exe_alu_result;
wire [31:0] mem_mem_result;

assign DATA_RISK_BUS = {exe_waddr, 
                        mem_waddr, 
                        wb_waddr, 
                        exe_mem_load, 
                        exe_mem_waddr, 
                        exe_alu_result, 
                        mem_mem_result, 
                        debug_wb_rf_wdata};
                      //   5          5          5          1           5                32              32                32
wire csr_re_id;
wire has_int;
wire ipi_int_in;
wire [31:0] csr_rvalue;
wire [31:0] csr_wmask;
wire [13:0] csr_num_exe;
wire [13:0] csr_num_mem;
wire csr_we_exe;
wire csr_we_mem;
wire csr_num_id_top;
wire [31:0] wb_vaddr;
wire [5:0]  wb_ecode;
wire [8:0]  wb_esubcode;
wire [31:0] wb_pc;
wire [31:0] csr_wvalue_wb;
wire [13:0] csr_num_wb;
wire [31:0] csr_wmask_wb;
wire [31:0] ertn_era_wb;
wire csr_we_wb;
wire [31:0] eentry_wb;
wire ertn_flush_wb_top;
wire wb_ex_top;
wire clear_top = ertn_flush_wb_top || wb_ex_top;
// CSR
CSR CSR(
    .clk             (clk           ),
    .ertn_flush      (ertn_flush_wb_top ),
    .reset           (reset         ),
    .csr_re          (csr_re_id     ),
    .csr_we          (csr_we_wb      ),
    .has_int         (has_int       ),
    .ipi_int_in      (ipi_int_in    ),
    .wb_vaddr        (wb_vaddr      ),
    .wb_ecode        (wb_ecode      ),
    .wb_esubcode     (wb_esubcode   ),
    .wb_pc           (wb_pc         ),
    .wb_ex           (wb_ex_top         ),
    .csr_num_r       (csr_num_id_top    ),
    .csr_num         (csr_num_wb     ),
    .csr_rvalue      (csr_rvalue    ),
    .csr_wvalue      (csr_wvalue_wb    ),
    .csr_wmask       (csr_wmask_wb   ) 
);
// IF stage
if_stage if_stage(
    .ertn_era_if    (ertn_era_wb    ),  
    .eentry_wb      (eentry_wb      ),
    .clear          (clear_top          ),
    .wb_ex          (wb_ex_top          ),
    .ertn_flush_wb  (ertn_flush_wb_top),

    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_wen  (inst_sram_wen  ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata)
    
);
// ID stage
wire [13:0] csr_num_exe_risk = csr_num_exe & {14{csr_we_exe}};
wire [13:0] csr_num_mem_risk = csr_num_mem & {14{csr_we_mem}};
wire [13:0] csr_num_wb_risk = csr_num_wb  & {14{csr_we_wb}};
id_stage id_stage(
    //CSR
    .clear          (clear_top      ),
    .csr_rvalue     (csr_rvalue     ),
    .csr_num_id     (csr_num_id_top     ),
    .csr_num_exe    (csr_num_exe_risk),
    .csr_num_mem    (csr_num_mem_risk),
    .csr_num_wb     (csr_num_wb_risk),
    //DATA_RISK_BUS
    .DATA_RISK_BUS  (DATA_RISK_BUS  ),
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   )
);
// EXE stage
exe_stage exe_stage(
    .clear          (clear_top      ),
    .csr_we_exe     (csr_we_exe),
    .csr_num_exe    (csr_num_exe),
    //DATA_RISK_BUS
    .exe_waddr      (exe_waddr      ),
    .exe_mem_load   (exe_mem_load   ),
    .exe_mem_waddr  (exe_mem_waddr  ),
    .exe_alu_result (exe_alu_result ),
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_en   (data_sram_en   ),
    .data_sram_wen  (data_sram_wen  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata)
);
// MEM stage
mem_stage mem_stage(
    .clear          (clear_top      ),
    .csr_we_mem     (csr_we_mem ),
    .csr_num_mem    (csr_num_mem),
    //DATA_RISK_BUS
    .mem_waddr      (mem_waddr      ),
    .mem_mem_result (mem_mem_result ),
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_rdata(data_sram_rdata)
);
// WB stage
wb_stage wb_stage(
    //to CSR
    .eentry_wb          (eentry_wb),
    .wb_ex              (wb_ex_top),
    .csr_wmask_wb       (csr_wmask_wb),
    .csr_we_wb          (csr_we_wb),
    .csr_num_wb         (csr_num_wb ),
    .csr_wvalue_wb      (csr_wvalue_wb ),
    .ertn_era_wb        (ertn_era_wb),
    .ertn_flush_wb      (ertn_flush_wb_top),
    .wb_vaddr           (wb_vaddr   ),
    .wb_pc              (wb_pc      ),
    .wb_ecode           (wb_ecode   ),
    .wb_esubcode        (wb_esubcode),
    //DATA_RISK_BUS
    .wb_waddr       (wb_waddr      ),
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

endmodule

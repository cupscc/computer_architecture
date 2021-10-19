`include "mycpu.h"

    
module CSR(
    input       clk,
    input       reset,
    input       csr_re,
    input       csr_we,
    input       ertn_flush,
    output      has_int,
    input [7:0] hw_int_in,                  //not right
    input       ipi_int_in,
    input  [5:0]     wb_ecode,
    input  [8:0]     wb_esubcode,
    input  [31:0]    wb_pc,
    input  wb_ex,
    input  [31:0]    wb_vaddr,
    input  [3:0]     csr_num_r,
    input  [3:0]     csr_num,
    output [31:0]    csr_rvalue,
    input  [31:0]    csr_wvalue,
    input  [31:0]    csr_wmask
);
//CRMD
wire [31:0] CRMD;
    reg [1:0]  csr_crmd_datm;
    reg [1:0]  csr_crmd_datf;
    reg        csr_crmd_pg;
    reg        csr_crmd_da;
    reg        csr_crmd_ie;    
    reg [1:0]  csr_crmd_plv;
    assign CRMD = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    always @(posedge clk) begin
        if (reset)begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie <= 1'b0;
        end
        else if (wb_ex)begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie <= 1'b0;
        end
        else if (ertn_flush)begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie  <= csr_prmd_pie;
        end
        else if (csr_we && csr_num==`CSR_CRMD)begin
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]  | ~csr_wmask[`CSR_CRMD_PLV]   & csr_crmd_plv;
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE] & csr_wvalue[`CSR_CRMD_PIE]   | ~csr_wmask[`CSR_CRMD_PIE]   & csr_crmd_ie;
        end
    end
//PRMD
wire [31:0] PRMD; 
    reg       csr_prmd_pie;
    reg [1:0] csr_prmd_pplv;
    assign PRMD = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie  <= csr_crmd_ie;
        end
        else if (csr_we && csr_num==`CSR_PRMD) begin
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV]   | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
            csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE]     | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
        end
    end
//ECFG
wire [31:0] ECFG;
    reg [12:0]  csr_ecfg_lie;
    assign ECFG = {19'b0, csr_ecfg_lie};
    always @(posedge clk) begin   
        if (reset)
            csr_ecfg_lie <= 13'b0;
        else if (csr_we && csr_num==`CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE]  | ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
    end
//ESTAT
wire [31:0] ESTAT;
    reg [8:0]   csr_estat_esubcode;      //what if [30:22]
    reg [5:0]   csr_estat_ecode;
    reg [12:0]  csr_estat_is;
    assign ESTAT = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    always @(posedge clk) begin
        if(reset)
            csr_estat_is[1:0] <= 2'b0;
        else if(csr_we && csr_num==`CSR_ESTAT)begin
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10] | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
            csr_estat_is[9:2] <= hw_int_in[7:0];
            csr_estat_is[10] <= 1'b0;
        end
        if (csr_tcfg_en && timer_cnt[31:0]==32'b0)
            csr_estat_is[11] <= 1'b1;
        else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])
            csr_estat_is[11] <= 1'b0;

        csr_estat_is[12] <= ipi_int_in;
    end
    //ECODE
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end
//ERA
wire [31:0] ERA;
    reg [31:0] csr_era_pc;
    assign ERA = csr_era_pc;
    always @(posedge clk) begin
        if (wb_ex)
            csr_era_pc <= wb_pc;
        else if (csr_we && csr_num==`CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC] | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
    end
//BADV
wire [31:0] BADV;
    reg [31:0] csr_badv_vaddr;
    assign BADV = csr_badv_vaddr;
    ////TODO
    wire wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE;
    always @(posedge clk) begin
        if (wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= (wb_ecode==`ECODE_ADE && wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
    end
//EENTRY
wire [31:0] EENTRY;
    reg [25:0] csr_eentry_va;
    assign EENTRY = {csr_eentry_va, 6'b0};
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA] 
                        | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
    end
//SAVE REGISTERS
wire [31:0] SAVE0;
wire [31:0] SAVE1;
wire [31:0] SAVE2;
wire [31:0] SAVE3;
    reg [31:0] csr_save0_data;
    reg [31:0] csr_save1_data;
    reg [31:0] csr_save2_data;
    reg [31:0] csr_save3_data;
    assign SAVE0  = csr_save0_data;    
    assign SAVE1  = csr_save1_data;
    assign SAVE2  = csr_save2_data;     
    assign SAVE3  = csr_save3_data;
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_SAVE0)
            csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
        if (csr_we && csr_num==`CSR_SAVE1)
            csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
        if (csr_we && csr_num==`CSR_SAVE2)
            csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
        if (csr_we && csr_num==`CSR_SAVE3)
            csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
    end
//TID
wire [31:0] TID;
    reg [31:0] csr_tid_tid;
    assign TID = csr_tid_tid;

    wire [31:0] coreid_in = 32'b0;

    always @(posedge clk) begin
        if (reset)
            csr_tid_tid <= coreid_in;
        else if (csr_we && csr_num==`CSR_TID)
            csr_tid_tid <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID]
                         | ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
    end
//TCFG
wire [31:0] TCFG;
    reg [29:0]  csr_tcfg_initval;
    reg csr_tcfg_periodic;
    reg csr_tcfg_en;
    assign TCFG = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    always @(posedge clk) begin
        if (reset)
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num==`CSR_TCFG)
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN]
                         | ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;
        
        if (csr_we && csr_num==`CSR_TCFG) begin
            csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD]    & csr_wvalue[`CSR_TCFG_PERIOD]
                                | ~csr_wmask[`CSR_TCFG_PERIOD]  & csr_tcfg_periodic;
            csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITV]     & csr_wvalue[`CSR_TCFG_INITV]
                                | ~csr_wmask[`CSR_TCFG_INITV]   & csr_tcfg_initval;
        end
    end

//TVAL
wire [31:0] TVAL;
    wire [31:0] csr_tval;
    wire [31:0] tcfg_next_value;
    reg [31:0] timer_cnt;
    assign csr_tval = timer_cnt[31:0];
    assign TVAL = csr_tval;
    assign tcfg_next_value = csr_wmask[31:0]&csr_wvalue[31:0]   | ~csr_wmask[31:0] &{csr_tcfg_initval,csr_tcfg_periodic, csr_tcfg_en};
    always @(posedge clk) begin
        if (reset)
        timer_cnt <= 32'hffffffff;
        else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
        else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
        
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
        end
    end
//TICLR
wire [31:0] TICLR;
    wire csr_ticlr_clr = 1'b0;
    assign TICLR = {31'b0, csr_ticlr_clr};
assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) != 12'b0) && (csr_crmd_ie == 1'b1);
//CSR READ
assign csr_rvalue = {32{csr_num_r == `CSR_PRMD  }} & PRMD  |
                    {32{csr_num_r == `CSR_ECFG  }} & ECFG  |
                    {32{csr_num_r == `CSR_ESTAT }} & ESTAT |
                    {32{csr_num_r == `CSR_ERA   }} & ERA   |
                    {32{csr_num_r == `CSR_BADV  }} & BADV  |
                    {32{csr_num_r == `CSR_EENTRY}} & EENTRY|
                    {32{csr_num_r == `CSR_SAVE0 }} & SAVE0 |
                    {32{csr_num_r == `CSR_SAVE1 }} & SAVE1 |
                    {32{csr_num_r == `CSR_SAVE2 }} & SAVE2 |
                    {32{csr_num_r == `CSR_SAVE3 }} & SAVE3 |
                    {32{csr_num_r == `CSR_TID   }} & TID   |
                    {32{csr_num_r == `CSR_TCFG  }} & TCFG  |
                    {32{csr_num_r == `CSR_TVAL  }} & TVAL  |
                    {32{csr_num_r == `CSR_TICLR }} & TICLR ;
  
endmodule
                      

                        
                      
                     




                        
                      









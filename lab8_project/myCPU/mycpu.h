`ifndef MYCPU_H
    `define MYCPU_H
//make all the bus 300 bits (convenient)
    `define BR_BUS_WD       33 //32 + 1
    `define FS_TO_DS_BUS_WD 300//64 + 1(exec_ADEF)
    `define DS_TO_ES_BUS_WD 300//151+ 3(mul_div) + 3(ld) + 2(st) + 4(exec_INE,exec_SYS,exec_BRK) + 14(csr_num) + 1(csr_we)
                               //                 8                          19
    `define ES_TO_MS_BUS_WD 300 //71 + 1 + 3(ld) + 2(st) + 2(ld_off) + 5(exec_ALE) + 32(vaddr) + 14(csr_num) + 1(csr_we)
                                //                8                                  51
    `define MS_TO_WS_BUS_WD 300 //70 + 5(execeptions) + 32(vaddr) + 14(csr_num) + 1(csr_we)
                                //                    51
    `define WS_TO_RF_BUS_WD 38
    `define DATA_RISK_BUS   117//15 + 1 + 5 + 32 * 3
    
    `define CSR_CRMD_PLV        1:0
    `define CSR_CRMD_PIE        2
    `define CSR_PRMD_PPLV       1:0
    `define CSR_PRMD_PIE        2
    `define CSR_ECFG_LIE        12:0
    `define CSR_ESTAT_IS10      1:0
    `define CSR_TICLR_CLR       11
    `define CSR_ERA_PC          31:0
    `define CSR_EENTRY_VA       25:0
    `define CSR_SAVE_DATA       31:0
    `define CSR_TID_TID         31:0
    `define CSR_TCFG_EN         0
    `define CSR_TCFG_PERIOD     1
    `define CSR_TCFG_INITV      31:2
    `define CSR_TCFG_INITVAL    31:2
//CSR NUM
`define CSR_CRMD        0
    `define CSR_PRMD    1
    `define CSR_ECFG    4
    `define CSR_ESTAT   5
    `define CSR_ERA     6
    `define CSR_BADV    7
    `define CSR_EENTRY  12
    `define CSR_SAVE0   48
    `define CSR_SAVE1   49
    `define CSR_SAVE2   50
    `define CSR_SAVE3   51
    `define CSR_TID     64
    `define CSR_TCFG    65
    `define CSR_TVAL    66
    `define CSR_TICLR   68
    //ECODE
    `define ECODE_ADE   8
    `define ESUBCODE_ADEF   0
    //`define ESUBCODE_ADEM   1
    `define ECODE_ALE   9
    `define ECODE_SYS   11
    `define ECODE_BRK   12
    `define ECODE_INE   13
`endif

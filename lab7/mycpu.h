`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       33 //32+1
    `define FS_TO_DS_BUS_WD 64
    `define DS_TO_ES_BUS_WD 159//151 + 3(mul_div) + 3(ld) + 2(st)
    `define ES_TO_MS_BUS_WD 79 //71 + 1 + 3(ld) + 2(st) + 2(ld_off)
    `define MS_TO_WS_BUS_WD 70 
    `define WS_TO_RF_BUS_WD 38
    `define DATA_RISK_BUS   117//15 + 1 + 5 + 32 * 3
`endif

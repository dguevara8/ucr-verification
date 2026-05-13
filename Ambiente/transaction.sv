class transaction;

    int cycle;

    logic [31:0] pc;
    logic [31:0] instr;
    logic [4:0]  rd;
    logic [31:0] wdata;
    logic        reg_write;
    logic        hlt;
    logic [3:0]  debug;

    function void print(string tag = "TR");
        $display("[%s] ciclo=%0d PC=%08h INSTR=%08h RD=x%0d WDATA=%08h WE=%0b HLT=%0b DBG=%0b",
                 tag, cycle, pc, instr, rd, wdata, reg_write, hlt, debug);
    endfunction

endclass
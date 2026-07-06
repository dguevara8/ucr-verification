// Interface simple para conectar el testbench con el DUT.
interface ifc_darksocv(
    input logic clk
);
    logic reset = 1'b1;

    // Senales observables del DUT para el monitor.
    logic [31:0] pc;
    logic [31:0] instr;
    logic [4:0]  rd;
    logic [31:0] wdata;
    logic [31:0] addr;
    logic [31:0] store_data;
    logic [31:0] next_pc;
    logic        reg_write;
    logic        mem_read;
    logic        mem_write;
    logic        branch_taken;
    logic        jump_taken;
    logic        is_branch;
    logic        is_jump;
    logic [3:0]  debug;
    logic        core_reset;
    logic        hlt;
    logic        finish_req;

endinterface
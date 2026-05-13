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
    logic        reg_write;
    logic [3:0]  debug;
    logic        core_reset;
    logic        hlt;
  
endinterface
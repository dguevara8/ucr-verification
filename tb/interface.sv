// Interface simple para conectar el testbench con el DUT.
interface ifc_darksocv(
    input logic clk
);
    logic reset = 1'b1;
endinterface

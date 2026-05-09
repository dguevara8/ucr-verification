// Interface simple para conectar el testbench con el DUT.
interface ifc_darksocv(input logic clk);

    logic reset = 1'b1;

    // Señales del DUT
    logic uart_tx;
    logic uart_rx;
    logic [3:0] led;
    logic [3:0] debug;

endinterface
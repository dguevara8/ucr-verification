class scoreboard #(
    parameter FIFO_ROWS         = 256,                 // Número de entradas que tiene el FIFO
    parameter FIFO_ROW_WIDTH    = 32,                  // Número de bits por entrada (ancho de bus)
    parameter ADDR_WIDTH        = $clog2(FIFO_ROWS)    // Ancho de puntero calculado
);

  logic [FIFO_ROW_WIDTH-1:0] SIM_MEMORY [$:256];

endclass
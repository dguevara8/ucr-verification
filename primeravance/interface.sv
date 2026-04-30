interface ifc_ram #(
    parameter FIFO_ROWS         = 256,                 // Número de entradas que tiene el FIFO
    parameter FIFO_ROW_WIDTH    = 32,                  // Número de bits por entrada (ancho de bus)
    parameter ADDR_WIDTH        = $clog2(FIFO_ROWS)    // Ancho de puntero calculado
) (    
  	input                         clk
    );
  
    logic                         reset;

    // Interfaz de escritura
    logic [FIFO_ROW_WIDTH-1:0]    wr_data;
    logic                         wr_en;
    logic [ADDR_WIDTH-1:0]        wr_addr;

    // Interfaz de lectura
    logic [FIFO_ROW_WIDTH-1:0]    rd_data;
    logic                         rd_en;
    logic [ADDR_WIDTH-1:0]        rd_addr;
endinterface
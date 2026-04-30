module flip_flop_ram #(
    parameter FIFO_ROWS         = 256,                 // Número de entradas que tiene el FIFO
    parameter FIFO_ROW_WIDTH    = 32,                  // Número de bits por entrada (ancho de bus)
    parameter ADDR_WIDTH        = $clog2(FIFO_ROWS)    // Ancho de puntero calculado
) (
    // Señales de funcionamiento básico
    input  logic                         clk,
    input  logic                         reset,

    // Interfaz de escritura
    input  logic [FIFO_ROW_WIDTH-1:0]    wr_data,
    input  logic                         wr_en,
    input  logic [ADDR_WIDTH-1:0]        wr_addr,

    // Interfaz de lectura
    output logic [FIFO_ROW_WIDTH-1:0]    rd_data,
    input  logic                         rd_en,
    input  logic [ADDR_WIDTH-1:0]        rd_addr
);

    // memoria del FIFO: FIFO_ROWS filas de FIFO_ROW_WIDTH bits
    logic [FIFO_ROWS-1:0][FIFO_ROW_WIDTH-1:0] memory ;

    always_ff @(posedge clk) begin
        if (reset) begin
            integer i;
            for (i = 0; i < FIFO_ROWS; i = i + 1) begin
                memory[i] <= '0;
            end
            rd_data <= '0;
        end
        else begin
            case ({wr_en, rd_en})
                // IDLE: no lectura ni escritura
                2'b00: begin
                    rd_data <= rd_data;
                end

                // Read only: leer desde rd_addr
                2'b01: begin
                    rd_data <= memory[rd_addr];
                end

                // Write only: escribir en wr_addr
                2'b10: begin
                    memory[wr_addr] <= wr_data;
                    rd_data <= rd_data;
                end

                // Read and write simultáneo: leer y escribir
                // Como se puede ver, se puede escribir y acceder a la misma posición de memoria,
                // pero la actualización del dato escrito se refleja hasta en el próximo ciclo
                2'b11: begin
                    rd_data <= memory[rd_addr];
                    memory[wr_addr] <= wr_data;
                end

                default: begin
                    rd_data <= rd_data;
                end
            endcase
        end
    end

endmodule

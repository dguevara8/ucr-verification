`timescale 1ns/1ps

module testbench;

    // Parámetros del DUT (usar los valores por defecto del módulo)
    localparam FIFO_ROWS      = 16;
    localparam FIFO_ROW_WIDTH = 32;
    localparam ADDR_WIDTH     = $clog2(FIFO_ROWS);

    // Señales del testbench
    logic clk;
    logic reset;

    logic [FIFO_ROW_WIDTH-1:0] wr_data;
    logic                      wr_en;
    logic [ADDR_WIDTH-1:0]     wr_addr;

    logic [FIFO_ROW_WIDTH-1:0] rd_data;
    logic                      rd_en;
    logic [ADDR_WIDTH-1:0]     rd_addr;

    // Instanciación del DUT
    flip_flop_ram #(
        .FIFO_ROWS(FIFO_ROWS),
        .FIFO_ROW_WIDTH(FIFO_ROW_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
        ) dut (
        .clk       (clk),
        .reset     (reset),
        .wr_data   (wr_data),
        .wr_en     (wr_en),
        .wr_addr   (wr_addr),
        .rd_data   (rd_data),
        .rd_en     (rd_en),
        .rd_addr   (rd_addr)
    );

    // Reloj: periodo 10ns
    initial clk = 0;
    always #5 clk = ~clk;

    // Monitor: mostrar actividad en cada flanco de reloj
    always_ff @(posedge clk) begin
        $display("[%0t] wr_en=%0b wr_addr=%0d wr_data=0x%0h | rd_en=%0b rd_addr=%0d rd_data=0x%0h",
                    $time, wr_en, wr_addr, wr_data, rd_en, rd_addr, rd_data);
    end

    // Stimulus
    initial begin
        // Dump para waveform (VCD)
        // Dump waves
        $dumpfile("dump.vcd");
        $dumpvars(1);

        // Inicialización
        reset      = 1;
        wr_en      = 0;
        rd_en      = 0;
        wr_data = '0;
        wr_addr    = '0;
        rd_addr    = '0;

        // Mantener reset unos ciclos
        repeat (4) @(posedge clk);
        reset = 0;
        @(posedge clk);

        // Escribir 8 palabras en direcciones 0..7
        for (int i = 0; i < 8; i++) begin
            @(posedge clk);
            wr_en      <= 1;
            wr_data <= 32'hA0 + i;
            wr_addr    <= i[ADDR_WIDTH-1:0];
            rd_en      <= 0;
        end

        // Desactivar escritura
        @(posedge clk);
        wr_en <= 0;

        // Leer las 8 palabras escritas (direcciones 0..7)
        for (int i = 0; i < 8; i++) begin
            @(posedge clk);
            rd_en   <= 1;
            rd_addr <= i[ADDR_WIDTH-1:0];
            wr_en   <= 0;
        end

        // Desactivar lectura
        @(posedge clk);
        rd_en <= 0;

        // Ejemplo de lectura y escritura simultánea:
        // escribir en addr=8 mientras se lee addr=0
        @(posedge clk);
        wr_en      <= 1;
        wr_data <= 32'hDEADBEEF;
        wr_addr    <= 8;
        rd_en      <= 1;
        rd_addr    <= 0;

        // Unos ciclos más para observar
        repeat (4) @(posedge clk);

        // Finalizar simulación
        $display("Fin de la simulación");
        #1 $finish;
    end

endmodule
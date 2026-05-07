//El estímulo es lo que se transmite, no como un protocolo, pero el
//elemento envuelto en el protocolo que se utiliza para ejercitar la lógica
//El protocolo puede ser enviar paquetes, pero el estímulo corresponde al 
//contenido de esos paquetes así como el tiempo de atraso entre ellos.
//En el caso de una memoria, las direcciones de lectura/escritura pueden
//ser parte del estímulo.
class stimulus #(
    parameter FIFO_ROWS         = 256,                 // Número de entradas que tiene el FIFO
    parameter FIFO_ROW_WIDTH    = 32,                  // Número de bits por entrada (ancho de bus)
    parameter ADDR_WIDTH        = $clog2(FIFO_ROWS)    // Ancho de puntero calculado
);
    randc logic [FIFO_ROW_WIDTH-1:0]  word;
    randc logic [ADDR_WIDTH-1:0]      wr_addr;
    randc logic [ADDR_WIDTH-1:0]      rd_addr;
endclass
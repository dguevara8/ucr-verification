//En este esquema de desarrollo vemos que el monitor es un 
//Monitor-Checker.

class monitor #(
    parameter FIFO_ROWS         = 256,                 // Número de entradas que tiene el FIFO
    parameter FIFO_ROW_WIDTH    = 32,                  // Número de bits por entrada (ancho de bus)
    parameter ADDR_WIDTH        = $clog2(FIFO_ROWS)    // Ancho de puntero calculado
);

  //En este esquema es normal instanciar un scoreboard, pero lo que pasa es que
  //se crea un puntero hacia el objeto real que está instanciado en el ambiente.
  // De esta forma podemos comunicarnos con él y acceder a sus datos.
  scoreboard scoreboard_obj;
  virtual ifc_ram ifc_ram_obj;
  logic [FIFO_ROW_WIDTH-1:0] read_word;

  //Necesitamos una interfaz virtual para observar el "mundo RTL"
  function new (virtual ifc_ram ifc_ram_obj, scoreboard scoreboard_obj);
    this.scoreboard_obj = scoreboard_obj;
    this.ifc_ram_obj = ifc_ram_obj;
  endfunction

  //Usamos un task porque este método debe consumir tiempo
  task check ();
    forever begin
      @(posedge ifc_ram_obj.clk);
      if (ifc_ram_obj.rd_en) begin
        $display("\nTiempo=%d || Monitor de lectura: Rd_en=1. Dirección de lectura %d", $time, ifc_ram_obj.rd_addr);
        read_word = scoreboard_obj.SIM_MEMORY[ifc_ram_obj.rd_addr];
        //Esperamos un ciclo de reloj porque el protocolo toma un ciclo en devolver el dato.
        @(posedge ifc_ram_obj.clk);
        #1;
        $display("Tiempo %d || Monitor de lectura: El dato leído corresponde a %d", $time, ifc_ram_obj.rd_data);
        if (ifc_ram_obj.rd_data != read_word) $display("Monitor de lectura: ERROR EL DATO NO COINCIDE. Teórico %d, Experimental %d", read_word, ifc_ram_obj.rd_data);
        else $display("Tiempo %d || Monitor de lectura: El dato sí coincide. Teórico %d, Experimental %d", $time, read_word, ifc_ram_obj.rd_data);
      end
    end
  endtask
endclass
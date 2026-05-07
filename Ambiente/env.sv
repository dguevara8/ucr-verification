class env #(
    parameter FIFO_ROWS         = 256,                 // Número de entradas que tiene el FIFO
    parameter FIFO_ROW_WIDTH    = 32,                  // Número de bits por entrada (ancho de bus)
    parameter ADDR_WIDTH        = $clog2(FIFO_ROWS)    // Ancho de puntero calculado
);
  //Se deben declarar los componentes de verificación que componen el ambiente

  virtual ifc_ram ifc_ram_obj;

  driver driver_obj;
  monitor monitor_obj;
  scoreboard scoreboard_obj;

  function new(virtual ifc_ram ifc_ram_obj);
    $display("Ambiente: Método creador del ambiente");
    this.ifc_ram_obj = ifc_ram_obj;
    scoreboard_obj = new();
    driver_obj  = new(ifc_ram_obj, scoreboard_obj);
    monitor_obj = new(ifc_ram_obj, scoreboard_obj);
    fork
      monitor_obj.check();
    join_none
  endfunction

  //Solo para propósitos de depuración.
  task execute ();
    driver_obj.reset();
    driver_obj.write_random_data();
    driver_obj.write_random_data();
    driver_obj.read_data();
    for (int i=0; i<256; i=i+1)begin
      driver_obj.write_data(i);
    end
    for (int i=0; i<256; i=i+1)begin
      driver_obj.read_data(i);
    end
    for (int i=0; i<256; i=i+1)begin
      $display("INSPECTOR ENV SCOREBOARD: Dato en fila %d es = %d", i, scoreboard_obj.SIM_MEMORY[i]);
    end   
  endtask

endclass
program testcase(ifc_ram ifc_ram_obj);
  env env_obj = new(ifc_ram_obj);

  initial begin
    env_obj.driver_obj.reset();
    env_obj.driver_obj.write_random_data();
    env_obj.driver_obj.write_random_data();
    env_obj.driver_obj.read_data();
    for (int i=0; i<256; i=i+1)begin
      env_obj.driver_obj.write_data(i);
    end
    for (int i=0; i<256; i=i+1)begin
      env_obj.driver_obj.read_data(i);
    end
    for (int i=0; i<256; i=i+1)begin
      $display("INSPECTOR ENV SCOREBOARD: Dato en fila %d es = %d", i, env_obj.scoreboard_obj.SIM_MEMORY[i]);
    end
  end
  
endprogram
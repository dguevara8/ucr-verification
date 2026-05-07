// Driver encargado de llevar el programa generado al archivo de memoria
// y controlar el reset externo del DUT.
class driver;
    stimulus stimulus_obj;
    virtual ifc_darksocv ifc_darksocv_obj;

    function new(virtual ifc_darksocv ifc_darksocv_obj);
        this.ifc_darksocv_obj = ifc_darksocv_obj;
    endfunction

    // Crea el programa aleatorio tipo R que se va a cargar en memoria.
    task build_program();
        $display("Driver: creando programa aleatorio tipo R");
        stimulus_obj = new();
        stimulus_obj.build_program();
        stimulus_obj.print_program();
    endtask

    // Escribe una instruccion por linea en formato hexadecimal.
    task write_mem_file();
        int fd;

        fd = $fopen("darksocv.mem", "w");
        if (fd == 0) begin
            $fatal(1, "[DRIVER] No se pudo abrir darksocv.mem para escritura");
        end

        foreach (stimulus_obj.instructions[i]) begin
            $fdisplay(fd, "%08h", stimulus_obj.instructions[i]);
        end

        $fclose(fd);
        $display("[DRIVER] Archivo darksocv.mem escrito con %0d instrucciones",
                 stimulus_obj.instructions.size());
    endtask

    // Carga el archivo generado dentro de la memoria interna del DUT.
    // Esto mantiene el RTL sin cambios y permite partir de un .mem vacio.
    task load_mem_file();
        $display("Driver: cargando darksocv.mem en la memoria interna del DUT");
        $readmemh("darksocv.mem", top.dut.MEM, 0);
    endtask

    // Aplica reset durante varios ciclos y luego lo libera.
    task reset();
        $display("Driver: Reset sequence");
        ifc_darksocv_obj.reset = 1'b1;
        @(posedge ifc_darksocv_obj.clk);
        repeat (10) @(posedge ifc_darksocv_obj.clk);

        $display("Driver: liberando reset");
        ifc_darksocv_obj.reset = 1'b0;
    endtask

    // Secuencia principal del driver.
    task run();
        build_program();
        write_mem_file();
        load_mem_file();
        reset();
        $display("[DRIVER] El procesador ya puede ejecutar darksocv.mem");
    endtask
endclass

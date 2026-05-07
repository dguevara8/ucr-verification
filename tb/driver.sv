// Driver encargado de llevar el programa generado al archivo de memoria
// y controlar el reset externo del DUT.
class driver;

    // Objeto stimulus que genera el programa RISC-V.
    stimulus stimulus_obj;

    // Interfaz virtual para acceder a clk y reset.
    virtual ifc_darksocv ifc_darksocv_obj;

    // Constructor.
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

    // Imprime el contenido del archivo darksocv.mem.
    task print_mem_file();

        int fd;
        string line;

        fd = $fopen("darksocv.mem", "r");

        if (fd == 0) begin
            $fatal(1, "[DRIVER] No se pudo abrir darksocv.mem para lectura");
        end

        $display("\n[DRIVER] Contenido de darksocv.mem:");

        while (!$feof(fd)) begin
            void'($fgets(line, fd));
            $write("%s", line);
        end

        $fclose(fd);

    endtask

    // Carga el archivo generado dentro de la memoria interna del DUT.
    task load_mem_file();

        $display("\n[DRIVER] Cargando darksocv.mem en top.dut.MEM");

        $readmemh("darksocv.mem", top.dut.MEM, 0);

    endtask

    // Imprime el contenido cargado dentro de la memoria interna del DUT.
    task print_dut_mem();

        int i;

        $display("\n[DRIVER] Contenido cargado en top.dut.MEM:");

        for (i = 0; i < stimulus_obj.instructions.size(); i++) begin
            $display("[DRIVER] MEM[%0d] = %08h",
                     i,
                     top.dut.MEM[i]);
        end

    endtask

    // Aplica reset durante varios ciclos y luego lo libera.
    task reset();

        $display("\n[DRIVER] Aplicando reset al DUT");

        ifc_darksocv_obj.reset = 1'b1;

        @(posedge ifc_darksocv_obj.clk);

        repeat (10) @(posedge ifc_darksocv_obj.clk);

        $display("[DRIVER] Liberando reset");

        ifc_darksocv_obj.reset = 1'b0;

    endtask

    // Secuencia principal del driver.
    task run();

        build_program();

        write_mem_file();

        print_mem_file();

        load_mem_file();

        print_dut_mem();

        reset();

        $display("\n[DRIVER] El procesador ya puede ejecutar darksocv.mem");

    endtask

endclass
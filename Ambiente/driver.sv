// Driver encargado de llevar el programa generado al archivo de memoria
// y controlar el reset externo del DUT.
class driver;

    stimulus stimulus_obj;

    virtual ifc_darksocv ifc_darksocv_obj;

    // Mailbox para enviar las instrucciones generadas al monitor de instrucciones.
    mailbox #(transaction) drv2imon;

    function new(virtual ifc_darksocv ifc_darksocv_obj,
                 mailbox #(transaction) drv2imon);
        this.ifc_darksocv_obj = ifc_darksocv_obj;
        this.drv2imon = drv2imon;
    endfunction

    task build_program();

        $display("Driver: creando programa aleatorio tipo R/tipo I");

        stimulus_obj = new();

        stimulus_obj.build_program();

        stimulus_obj.print_program();

    endtask

    // Envia al instruction monitor las instrucciones antes de que el DUT las ejecute.
    task publish_program_to_instruction_monitor();

        transaction tr;

        $display("\n[DRIVER] Enviando programa al monitor de instrucciones");

        foreach (stimulus_obj.instructions[i]) begin
            tr = new();

            tr.cycle = i;
            tr.pc = i * 4;
            tr.instr = stimulus_obj.instructions[i];
            tr.rd = stimulus_obj.instructions[i][11:7];
            tr.wdata = 32'h00000000;
            tr.reg_write = 1'b0;
            tr.hlt = 1'b0;
            tr.debug = 4'h0;

            drv2imon.put(tr);

            $display("[DRIVER] PRE_DUT instr[%0d] PC=%08h INSTR=%08h RD=x%0d",
                     i, tr.pc, tr.instr, tr.rd);
        end

    endtask

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

    task load_mem_file();

        $display("\n[DRIVER] Cargando darksocv.mem en top.dut.MEM");

        $readmemh("darksocv.mem", top.dut.MEM, 0);

    endtask

    task print_dut_mem();

        int i;

        $display("\n[DRIVER] Contenido cargado en top.dut.MEM:");

        for (i = 0; i < stimulus_obj.instructions.size(); i++) begin
            $display("[DRIVER] MEM[%0d] = %08h",
                     i,
                     top.dut.MEM[i]);
        end

    endtask

    task reset();

        $display("\n[DRIVER] Aplicando reset al DUT");

        ifc_darksocv_obj.reset = 1'b1;

        @(posedge ifc_darksocv_obj.clk);

        repeat (10) @(posedge ifc_darksocv_obj.clk);

        $display("[DRIVER] Liberando reset");

        ifc_darksocv_obj.reset = 1'b0;

    endtask

    task run();

        build_program();

        publish_program_to_instruction_monitor();

        write_mem_file();

        print_mem_file();

        load_mem_file();

        print_dut_mem();

        reset();

        $display("\n[DRIVER] El procesador ya puede ejecutar darksocv.mem");

    endtask

endclass
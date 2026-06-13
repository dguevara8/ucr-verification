// Driver encargado de llevar el programa generado al archivo de memoria
// y controlar el reset externo del DUT.
class riscv_driver extends uvm_driver #(riscv_transaction);

    `uvm_component_utils(riscv_driver)

    localparam int PROGRAM_SIZE = 95;

    virtual ifc_darksocv ifc_darksocv_obj;
  
    // En UVM traducimos mailbox a analysis_port para enviar instrucciones esperadas al scoreboard/premonitor.
    uvm_analysis_port #(riscv_transaction) drv2imon_port;

    logic [31:0] instructions[$];

    function new(string name = "riscv_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        drv2imon_port = new("drv2imon_port", this);

        if (!uvm_config_db #(virtual ifc_darksocv)::get(this, "", "ifc_darksocv_obj", ifc_darksocv_obj)) begin
            `uvm_fatal(get_type_name(), "No se encontro la interfaz virtual ifc_darksocv_obj")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        riscv_transaction tr;

        super.run_phase(phase);

        phase.raise_objection(this);

        `uvm_info(
            get_type_name(),
            $sformatf("Driver: recibiendo programa aleatorio tipo R/tipo I/tipo U, PROGRAM_SIZE=%0d",
                      PROGRAM_SIZE),
            UVM_MEDIUM
        )

        instructions.delete();

        repeat (PROGRAM_SIZE) begin
            seq_item_port.get_next_item(tr);

            instructions.push_back(tr.instr);

            publish_instruction_to_instruction_monitor(tr);

            `uvm_info(
                get_type_name(),
                $sformatf("PRE_DUT instr[%0d] PC=%08h INSTR=%08h RD=x%0d",
                          tr.cycle, tr.pc, tr.instr, tr.rd),
                UVM_MEDIUM
            )

            seq_item_port.item_done();
        end

        write_mem_file();
        print_mem_file();
        load_mem_file();
        print_dut_mem();
        reset();

        `uvm_info(get_type_name(), "El procesador ya puede ejecutar darksocv.mem", UVM_LOW)

        phase.drop_objection(this);
    endtask

    // Equivalente a drv2imon.put(tr)
    task publish_instruction_to_instruction_monitor(riscv_transaction tr);
        riscv_transaction tr_copy;

        tr_copy = riscv_transaction::type_id::create("tr_copy");

        tr_copy.cycle     = tr.cycle;
        tr_copy.pc        = tr.pc;
        tr_copy.instr     = tr.instr;
        tr_copy.rd        = tr.rd;
        tr_copy.wdata     = 32'h00000000;
        tr_copy.reg_write = 1'b0;
        tr_copy.hlt       = 1'b0;
        tr_copy.debug     = 4'h0;

        drv2imon_port.write(tr_copy);
    endtask

    task write_mem_file();
        int fd;

        fd = $fopen("darksocv.mem", "w");

        if (fd == 0) begin
            `uvm_fatal(get_type_name(), "No se pudo abrir darksocv.mem para escritura")
        end

        foreach (instructions[i]) begin
            $fdisplay(fd, "%08h", instructions[i]);
        end

        $fclose(fd);

        `uvm_info(
            get_type_name(),
            $sformatf("Archivo darksocv.mem escrito con %0d instrucciones", instructions.size()),
            UVM_LOW
        )
    endtask

    task print_mem_file();
        int fd;
        string line;

        fd = $fopen("darksocv.mem", "r");

        if (fd == 0) begin
            `uvm_fatal(get_type_name(), "No se pudo abrir darksocv.mem para lectura")
        end

        `uvm_info(get_type_name(), "Contenido de darksocv.mem:", UVM_LOW)

        while (!$feof(fd)) begin
            void'($fgets(line, fd));
            $write("%s", line);
        end

        $fclose(fd);
    endtask

    task load_mem_file();
        `uvm_info(get_type_name(), "Cargando darksocv.mem en top.dut.MEM", UVM_LOW)

        $readmemh("darksocv.mem", top.dut.MEM, 0);
    endtask

    task print_dut_mem();
        int i;

        `uvm_info(get_type_name(), "Contenido cargado en top.dut.MEM:", UVM_LOW)

        for (i = 0; i < instructions.size(); i++) begin
            `uvm_info(
                get_type_name(),
                $sformatf("MEM[%0d] = %08h", i, top.dut.MEM[i]),
                UVM_LOW
            )
        end
    endtask

    task reset();
        `uvm_info(get_type_name(), "Aplicando reset al DUT", UVM_LOW)

        ifc_darksocv_obj.reset = 1'b1;

        @(posedge ifc_darksocv_obj.clk);

        repeat (10) @(posedge ifc_darksocv_obj.clk);

        `uvm_info(get_type_name(), "Liberando reset", UVM_LOW)

        ifc_darksocv_obj.reset = 1'b0;
    endtask

endclass

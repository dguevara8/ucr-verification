// Test principal del avance #3.
class base_test extends uvm_test;

    `uvm_component_utils(base_test)

    riscv_env env_obj;
    virtual ifc_darksocv ifc_darksocv_obj;

    function new(string name = "base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env_obj = riscv_env::type_id::create("env_obj", this);

        if (!uvm_config_db #(virtual ifc_darksocv)::get(this, "", "ifc_darksocv_obj", ifc_darksocv_obj)) begin
            `uvm_fatal(get_type_name(), "No se encontro la interfaz virtual ifc_darksocv_obj")
        end
    endfunction

    virtual function program_kind_e get_program_kind();
        return PROGRAM_MIXED;
    endfunction

    virtual task run_phase(uvm_phase phase);
        riscv_sequence sequence_obj;

        super.run_phase(phase);

        phase.raise_objection(this);

        sequence_obj = riscv_sequence::type_id::create("sequence_obj");
        sequence_obj.program_kind = get_program_kind();
        sequence_obj.start(env_obj.agent_obj.sequencer_obj);

        // Tiempo de observacion extendido para permitir que el core interno
        // salga de reset y ejecute el programa generado.
        fork
            begin
                repeat (6000) @(posedge ifc_darksocv_obj.clk);
            end
            begin
                wait (ifc_darksocv_obj.finish_req === 1'b1);
                `uvm_info(get_type_name(), "[TEST] DUT solicito fin de simulacion", UVM_LOW)
            end
        join_any
        disable fork;

        `uvm_info(get_type_name(), "[TEST] Fin de la simulacion", UVM_LOW)

        env_obj.scoreboard_obj.print_fail_summary(get_type_name());

        phase.drop_objection(this);
    endtask

endclass

class r_test extends base_test;

    `uvm_component_utils(r_test)

    function new(string name = "r_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function program_kind_e get_program_kind();
        return PROGRAM_R;
    endfunction

endclass

class i_test extends base_test;

    `uvm_component_utils(i_test)

    function new(string name = "i_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function program_kind_e get_program_kind();
        return PROGRAM_I;
    endfunction

endclass

class u_test extends base_test;

    `uvm_component_utils(u_test)

    function new(string name = "u_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function program_kind_e get_program_kind();
        return PROGRAM_U;
    endfunction

endclass

class load_test extends base_test;

    `uvm_component_utils(load_test)

    function new(string name = "load_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function program_kind_e get_program_kind();
        return PROGRAM_LOAD;
    endfunction

endclass

class store_test extends base_test;

    `uvm_component_utils(store_test)

    function new(string name = "store_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function program_kind_e get_program_kind();
        return PROGRAM_STORE;
    endfunction

endclass

class branch_test extends base_test;

    `uvm_component_utils(branch_test)

    function new(string name = "branch_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function program_kind_e get_program_kind();
        return PROGRAM_BRANCH;
    endfunction

endclass

class jump_test extends base_test;

    `uvm_component_utils(jump_test)

    function new(string name = "jump_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function program_kind_e get_program_kind();
        return PROGRAM_JUMP;
    endfunction

endclass

class mixed_test extends base_test;

    `uvm_component_utils(mixed_test)

    function new(string name = "mixed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function program_kind_e get_program_kind();
        return PROGRAM_MIXED;
    endfunction

endclass

class reset_test extends mixed_test;

    `uvm_component_utils(reset_test)

    function new(string name = "reset_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        riscv_sequence sequence_obj;
        logic [31:0] pc_before_reset;

        phase.raise_objection(this);

        sequence_obj = riscv_sequence::type_id::create("sequence_obj");
        sequence_obj.program_kind = get_program_kind();
        sequence_obj.start(env_obj.agent_obj.sequencer_obj);

        repeat (80) @(posedge ifc_darksocv_obj.clk);
        pc_before_reset = ifc_darksocv_obj.pc;

        `uvm_info(
            get_type_name(),
            $sformatf("[RESET_TEST] Aplicando segundo reset. PC antes=%08h", pc_before_reset),
            UVM_LOW
        )

        ifc_darksocv_obj.reset = 1'b1;
        repeat (10) @(posedge ifc_darksocv_obj.clk);

        if (ifc_darksocv_obj.core_reset !== 1'b1) begin
            `uvm_error(get_type_name(), "[RESET_TEST] core_reset no se activo durante reset externo")
        end

        ifc_darksocv_obj.reset = 1'b0;
        repeat (2) @(posedge ifc_darksocv_obj.clk);

        if (ifc_darksocv_obj.pc[1:0] !== 2'b00) begin
            `uvm_error(get_type_name(), "[RESET_TEST] PC no esta alineado despues del reset")
        end

        if (ifc_darksocv_obj.pc > 32'h00000020) begin
            `uvm_error(
                get_type_name(),
                $sformatf("[RESET_TEST] PC no regreso a la zona inicial. antes=%08h despues=%08h",
                          pc_before_reset,
                          ifc_darksocv_obj.pc)
            )
        end else begin
            `uvm_info(
                get_type_name(),
                $sformatf("[RESET_TEST] Reset verificado. PC despues=%08h", ifc_darksocv_obj.pc),
                UVM_LOW
            )
        end

        env_obj.scoreboard_obj.print_fail_summary(get_type_name());
        phase.drop_objection(this);
    endtask

endclass

class clock_test extends base_test;

    `uvm_component_utils(clock_test)

    function new(string name = "clock_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function program_kind_e get_program_kind();
        return PROGRAM_R;
    endfunction

    task change_clock_during_run();
        real periods[4];

        periods[0] = 5.0;
        periods[1] = 10.0;
        periods[2] = 20.0;
        periods[3] = 50.0;

        foreach (periods[i]) begin
            $root.top.set_clock_period_ns(periods[i]);
            `uvm_info(
                get_type_name(),
                $sformatf("[CLOCK_TEST] Periodo activo=%0.0f ns", periods[i]),
                UVM_LOW
            )
            repeat (700) @(posedge ifc_darksocv_obj.clk);
        end
    endtask

    virtual task run_phase(uvm_phase phase);
        riscv_sequence sequence_obj;

        phase.raise_objection(this);

        fork
            change_clock_during_run();
        join_none

        sequence_obj = riscv_sequence::type_id::create("sequence_obj");
        sequence_obj.program_kind = get_program_kind();
        sequence_obj.start(env_obj.agent_obj.sequencer_obj);

        repeat (3500) @(posedge ifc_darksocv_obj.clk);

        if (ifc_darksocv_obj.pc[1:0] !== 2'b00) begin
            `uvm_error(get_type_name(), "[CLOCK_TEST] PC no alineado durante variacion de reloj")
        end else begin
            `uvm_info(
                get_type_name(),
                $sformatf("[CLOCK_TEST] Variacion de reloj completada, PC=%08h", ifc_darksocv_obj.pc),
                UVM_LOW
            )
        end

        env_obj.scoreboard_obj.print_fail_summary(get_type_name());
        phase.drop_objection(this);
    endtask

endclass

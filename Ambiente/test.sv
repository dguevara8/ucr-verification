// Test principal del avance #2.
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

    virtual task run_phase(uvm_phase phase);
        riscv_sequence sequence_obj;

        super.run_phase(phase);

        phase.raise_objection(this);

        sequence_obj = riscv_sequence::type_id::create("sequence_obj");
        sequence_obj.start(env_obj.agent_obj.sequencer_obj);

      	// Tiempo de observacion extendido para permitir que el core interno
        // salga de reset y ejecute varias instrucciones antes de finalizar.
        repeat (1000) @(posedge ifc_darksocv_obj.clk);

      `uvm_info(get_type_name(), "[TEST] Fin de la simulacion", UVM_LOW)

        phase.drop_objection(this);
    endtask

endclass

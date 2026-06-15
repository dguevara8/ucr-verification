class riscv_agent extends uvm_agent;

    `uvm_component_utils(riscv_agent)

    riscv_sequencer sequencer_obj;
    riscv_driver    driver_obj;
    riscv_monitor   monitor_obj;

    function new(string name = "riscv_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sequencer_obj = riscv_sequencer::type_id::create("sequencer_obj", this);
        driver_obj    = riscv_driver::type_id::create("driver_obj", this);
        monitor_obj   = riscv_monitor::type_id::create("monitor_obj", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        driver_obj.seq_item_port.connect(sequencer_obj.seq_item_export);
    endfunction

endclass
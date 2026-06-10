class riscv_env extends uvm_env;

    `uvm_component_utils(riscv_env)

    riscv_agent      agent_obj;
    riscv_scoreboard scoreboard_obj;
    riscv_subscriber subscriber_obj;

    function new(string name = "riscv_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent_obj = riscv_agent::type_id::create("agent_obj", this);
        scoreboard_obj = riscv_scoreboard::type_id::create("scoreboard_obj", this);
        subscriber_obj = riscv_subscriber::type_id::create("subscriber_obj", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        agent_obj.driver_obj.drv2imon_port.connect(scoreboard_obj.expected_imp);
        agent_obj.monitor_obj.mon2scb_port.connect(scoreboard_obj.actual_imp);
        agent_obj.monitor_obj.mon2sub_port.connect(subscriber_obj.analysis_export);
    endfunction

endclass

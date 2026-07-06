class riscv_transaction extends uvm_sequence_item;

    int cycle;

    rand logic [31:0] pc;
    rand logic [31:0] instr;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [31:0] wdata;
    logic [31:0] addr;
    logic [31:0] store_data;
    logic [31:0] next_pc;
    logic        reg_write;
    logic        mem_read;
    logic        mem_write;
    logic        branch_taken;
    logic        jump_taken;
    logic        hlt;
    logic [3:0]  debug;

    `uvm_object_utils_begin(riscv_transaction)
        `uvm_field_int(cycle,        UVM_ALL_ON)
        `uvm_field_int(pc,           UVM_ALL_ON)
        `uvm_field_int(instr,        UVM_ALL_ON)
        `uvm_field_int(rd,           UVM_ALL_ON)
        `uvm_field_int(rs1,          UVM_ALL_ON)
        `uvm_field_int(rs2,          UVM_ALL_ON)
        `uvm_field_int(wdata,        UVM_ALL_ON)
        `uvm_field_int(addr,         UVM_ALL_ON)
        `uvm_field_int(store_data,   UVM_ALL_ON)
        `uvm_field_int(next_pc,      UVM_ALL_ON)
        `uvm_field_int(reg_write,    UVM_ALL_ON)
        `uvm_field_int(mem_read,     UVM_ALL_ON)
        `uvm_field_int(mem_write,    UVM_ALL_ON)
        `uvm_field_int(branch_taken, UVM_ALL_ON)
        `uvm_field_int(jump_taken,   UVM_ALL_ON)
        `uvm_field_int(hlt,          UVM_ALL_ON)
        `uvm_field_int(debug,        UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "riscv_transaction");
        super.new(name);
    endfunction

endclass
module darksocv_checkers(ifc_darksocv ifc_darksocv_obj);

    property no_unknown_fetch_control;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset)
        !$isunknown({
            ifc_darksocv_obj.pc,
            ifc_darksocv_obj.instr,
            ifc_darksocv_obj.rd,
            ifc_darksocv_obj.reg_write,
            ifc_darksocv_obj.mem_read,
            ifc_darksocv_obj.mem_write,
            ifc_darksocv_obj.branch_taken,
            ifc_darksocv_obj.jump_taken,
            ifc_darksocv_obj.hlt
        });
    endproperty

    assert property (no_unknown_fetch_control)
        else $error("[CHECKER_ASSERT] Hay X/Z en senales de control observadas");

    property pc_aligned;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset)
        ifc_darksocv_obj.pc[1:0] == 2'b00;
    endproperty

    assert property (pc_aligned)
        else $error("[CHECKER_ASSERT] PC no alineado: %08h", ifc_darksocv_obj.pc);

    property next_pc_aligned_on_control_flow;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset || ifc_darksocv_obj.hlt)
        (ifc_darksocv_obj.branch_taken || ifc_darksocv_obj.jump_taken) |->
            (ifc_darksocv_obj.next_pc[1:0] == 2'b00);
    endproperty

    assert property (next_pc_aligned_on_control_flow)
        else $error("[CHECKER_ASSERT] NEXT_PC no alineado en branch/jump: %08h", ifc_darksocv_obj.next_pc);

    property no_write_x0;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset || ifc_darksocv_obj.hlt)
        ifc_darksocv_obj.reg_write |-> (ifc_darksocv_obj.rd != 5'd0);
    endproperty

    assert property (no_write_x0)
        else $error("[CHECKER_ASSERT] Escritura invalida a x0");

    property writeback_data_known;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset || ifc_darksocv_obj.hlt)
        ifc_darksocv_obj.reg_write |-> !$isunknown(ifc_darksocv_obj.wdata);
    endproperty

    assert property (writeback_data_known)
        else $error("[CHECKER_ASSERT] WDATA tiene X/Z durante writeback");

    property mem_addr_known;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset || ifc_darksocv_obj.hlt)
        (ifc_darksocv_obj.mem_read || ifc_darksocv_obj.mem_write) |->
            !$isunknown(ifc_darksocv_obj.addr);
    endproperty

    assert property (mem_addr_known)
        else $error("[CHECKER_ASSERT] Direccion de memoria con X/Z");

    property mem_addr_word_aligned;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset || ifc_darksocv_obj.hlt)
        (ifc_darksocv_obj.mem_read || ifc_darksocv_obj.mem_write) |->
            (ifc_darksocv_obj.addr[1:0] == 2'b00);
    endproperty

    assert property (mem_addr_word_aligned)
        else $error("[CHECKER_ASSERT] Acceso de memoria no alineado: %08h", ifc_darksocv_obj.addr);

    property mem_read_write_exclusive;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset || ifc_darksocv_obj.hlt)
        !(ifc_darksocv_obj.mem_read && ifc_darksocv_obj.mem_write);
    endproperty

    assert property (mem_read_write_exclusive)
        else $error("[CHECKER_ASSERT] Lectura y escritura de memoria activas al mismo tiempo");

    property store_data_known;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset || ifc_darksocv_obj.hlt)
        ifc_darksocv_obj.mem_write |-> !$isunknown(ifc_darksocv_obj.store_data);
    endproperty

    assert property (store_data_known)
        else $error("[CHECKER_ASSERT] STORE_DATA tiene X/Z durante SW");

    property branch_taken_only_when_branch;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset || ifc_darksocv_obj.hlt)
        ifc_darksocv_obj.branch_taken |-> ifc_darksocv_obj.is_branch;
      endproperty

    assert property (branch_taken_only_when_branch)
        else $error("[CHECKER_ASSERT] branch_taken activo sin instruccion branch");

    property jump_taken_only_when_jump;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset || ifc_darksocv_obj.hlt)
        ifc_darksocv_obj.jump_taken |-> ifc_darksocv_obj.is_jump;
    endproperty

    assert property (jump_taken_only_when_jump)
        else $error("[CHECKER_ASSERT] jump_taken activo sin instruccion jump");

    property branch_jump_exclusive;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset || ifc_darksocv_obj.hlt)
        !(ifc_darksocv_obj.is_branch && ifc_darksocv_obj.is_jump);
    endproperty

    assert property (branch_jump_exclusive)
        else $error("[CHECKER_ASSERT] Branch y jump activos en el mismo ciclo");

endmodule

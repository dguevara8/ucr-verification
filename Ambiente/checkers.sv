module darksocv_checkers(ifc_darksocv ifc_darksocv_obj);

    property no_unknown_control;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset)
        !$isunknown({
            ifc_darksocv_obj.pc,
            ifc_darksocv_obj.instr,
            ifc_darksocv_obj.rd,
            ifc_darksocv_obj.wdata,
            ifc_darksocv_obj.reg_write,
            ifc_darksocv_obj.hlt,
            ifc_darksocv_obj.debug
        });
    endproperty

    assert property (no_unknown_control)
        else $error("[CHECKER] Hay X/Z en senales observadas del DUT");

    property pc_aligned;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset)
        ifc_darksocv_obj.pc[1:0] == 2'b00;
    endproperty

    assert property (pc_aligned)
        else $error("[CHECKER] PC no alineado: %08h", ifc_darksocv_obj.pc);

    property no_write_x0;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset)
        ifc_darksocv_obj.reg_write |-> (ifc_darksocv_obj.rd != 5'd0);
    endproperty

    assert property (no_write_x0)
        else $error("[CHECKER] Escritura invalida a x0");

endmodule
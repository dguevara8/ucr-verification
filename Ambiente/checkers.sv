class riscv_checker;

    mailbox #(transaction) mon2chk;
    scoreboard scoreboard_obj;

    int pass_count;
    int fail_count;

    function new(mailbox #(transaction) mon2chk,
                 scoreboard scoreboard_obj);
        this.mon2chk = mon2chk;
        this.scoreboard_obj = scoreboard_obj;

        pass_count = 0;
        fail_count = 0;
    endfunction

    task run();

        transaction tr;

        forever begin
            mon2chk.get(tr);

            scoreboard_obj.calculate_expected(tr);

            if (!scoreboard_obj.expected_valid) begin
                $error("[CHECKER] Instruccion no soportada. PC=%08h INSTR=%08h",
                       tr.pc, tr.instr);
                fail_count++;
            end
            else if (tr.rd !== scoreboard_obj.expected_rd) begin
                $error("[CHECKER] RD incorrecto. PC=%08h INSTR=%08h DUT_RD=x%0d ESPERADO=x%0d",
                       tr.pc,
                       tr.instr,
                       tr.rd,
                       scoreboard_obj.expected_rd);
                fail_count++;
            end
            else if (tr.wdata !== scoreboard_obj.expected_wdata) begin
                $error("[CHECKER] WDATA incorrecto. PC=%08h INSTR=%08h RD=x%0d DUT=%08h ESPERADO=%08h",
                       tr.pc,
                       tr.instr,
                       tr.rd,
                       tr.wdata,
                       scoreboard_obj.expected_wdata);
                fail_count++;
            end
            else begin
                $display("[CHECKER] PASS PC=%08h INSTR=%08h x%0d=%08h",
                         tr.pc,
                         tr.instr,
                         tr.rd,
                         tr.wdata);
                pass_count++;
            end
        end

    endtask

    function void report();
        $display("\n================ CHECKER REPORT ================");
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);
        $display("================================================\n");
    endfunction

endclass


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
        else $error("[CHECKER_ASSERT] Hay X/Z en senales observadas del DUT");

    property pc_aligned;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset)
        ifc_darksocv_obj.pc[1:0] == 2'b00;
    endproperty

    assert property (pc_aligned)
        else $error("[CHECKER_ASSERT] PC no alineado: %08h", ifc_darksocv_obj.pc);

    property no_write_x0;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset)
        ifc_darksocv_obj.reg_write |-> (ifc_darksocv_obj.rd != 5'd0);
    endproperty

    assert property (no_write_x0)
        else $error("[CHECKER_ASSERT] Escritura invalida a x0");

endmodule


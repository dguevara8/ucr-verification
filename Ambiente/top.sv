module top();

    import uvm_pkg::*;

    logic clk;
    string selected_test;
    real clock_half_period_ns = 5.0;

    wire uart_tx;
    wire uart_rx;
    wire [3:0] led;
    wire [3:0] debug;

    assign uart_rx = 1'b1;

    initial begin
        clk = 1'b0;
        forever begin
            #(clock_half_period_ns) clk = ~clk;
        end
    end

    task set_clock_period_ns(real period_ns);
        if (period_ns <= 0.0) begin
            `uvm_error("top", $sformatf("Periodo de reloj invalido: %0f ns", period_ns))
        end else begin
            clock_half_period_ns = period_ns / 2.0;
            `uvm_info("top", $sformatf("Clock period configurado a %0f ns", period_ns), UVM_LOW)
        end
    endtask

    ifc_darksocv ifc_darksocv_obj(clk);
    darksocv_checkers checkers_obj(ifc_darksocv_obj);

    // DUT principal del proyecto.
    darksocv dut(
        .XCLK(clk),
        .XRES(ifc_darksocv_obj.reset),
        .UART_RXD(uart_rx),
        .UART_TXD(uart_tx),
        .LED(led),
        .DEBUG(debug)
    );

    // Conexion jerarquica de senales observables para el monitor.
    always_comb begin
        ifc_darksocv_obj.pc = dut.core0.PC;
        ifc_darksocv_obj.instr = dut.core0.XIDATA;
        ifc_darksocv_obj.rd = {1'b0, dut.core0.DPTR};
        ifc_darksocv_obj.reg_write =
            !dut.core0.XRES &&
            !dut.HLT &&
            (dut.core0.LCC || dut.core0.AUIPC || dut.core0.JAL ||
             dut.core0.JALR || dut.core0.LUI || dut.core0.MCC ||
             dut.core0.RCC) &&
            (dut.core0.DPTR != 0);

        if (dut.core0.LCC) begin
            ifc_darksocv_obj.wdata = dut.core0.LDATA;
        end else if (dut.core0.AUIPC) begin
            ifc_darksocv_obj.wdata = dut.core0.PCSIMM;
        end else if (dut.core0.JAL || dut.core0.JALR) begin
            ifc_darksocv_obj.wdata = dut.core0.NXPC;
        end else if (dut.core0.LUI) begin
            ifc_darksocv_obj.wdata = dut.core0.SIMM;
        end else if (dut.core0.MCC || dut.core0.RCC) begin
            ifc_darksocv_obj.wdata = dut.core0.RMDATA;
        end else begin
            ifc_darksocv_obj.wdata = 32'h00000000;
        end

        ifc_darksocv_obj.addr = dut.core0.DADDR;
        ifc_darksocv_obj.store_data = dut.core0.DATAO;
        ifc_darksocv_obj.next_pc = dut.core0.NXPC;
        ifc_darksocv_obj.mem_read = dut.core0.LCC && !dut.HLT;
        ifc_darksocv_obj.mem_write = dut.core0.SCC && !dut.HLT;
        ifc_darksocv_obj.is_branch = dut.core0.BCC && !dut.HLT;
        ifc_darksocv_obj.is_jump = (dut.core0.JAL || dut.core0.JALR) && !dut.HLT;
        ifc_darksocv_obj.branch_taken = dut.core0.BCC && dut.core0.JREQ && !dut.HLT;
        ifc_darksocv_obj.jump_taken = (dut.core0.JAL || dut.core0.JALR) && dut.core0.JREQ && !dut.HLT;

        ifc_darksocv_obj.debug = dut.KDEBUG;
        ifc_darksocv_obj.core_reset = dut.core0.XRES;
        ifc_darksocv_obj.hlt = dut.HLT;
        ifc_darksocv_obj.finish_req = dut.FINISH_REQ;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, top);

        uvm_config_db #(virtual ifc_darksocv)::set(
            null,
            "",
            "ifc_darksocv_obj",
            ifc_darksocv_obj
        );

        if ($value$plusargs("UVM_TESTNAME=%s", selected_test)) begin
            run_test();
        end else begin
            run_test("base_test");
        end
    end

endmodule

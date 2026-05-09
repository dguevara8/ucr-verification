module top();
    logic clk;

    wire uart_tx;
    wire uart_rx;
    wire [3:0] led;
    wire [3:0] debug;

    assign uart_rx = 1'b1;

    initial begin
        clk = 1'b0;
        forever begin
            #5 clk = ~clk;
        end
    end

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

        ifc_darksocv_obj.debug = dut.KDEBUG;
        ifc_darksocv_obj.core_reset = dut.core0.XRES;
        ifc_darksocv_obj.hlt = dut.HLT;
    end

    // Test case.
    testcase test(ifc_darksocv_obj);
endmodule
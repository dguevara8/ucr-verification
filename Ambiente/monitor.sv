class monitor;

    virtual ifc_darksocv ifc_darksocv_obj;
    mailbox #(transaction) mon2scb;

    int cycle_count;
    logic [31:0] last_pc;
    logic [31:0] last_instr;
    logic        last_reset;
    logic        last_core_reset;

    function new(virtual ifc_darksocv ifc_darksocv_obj,
                 mailbox #(transaction) mon2scb);
        this.ifc_darksocv_obj = ifc_darksocv_obj;
        this.mon2scb = mon2scb;

        cycle_count = 0;
        last_pc = 32'hFFFF_FFFF;
        last_instr = 32'hFFFF_FFFF;
        last_reset = 1'b1;
        last_core_reset = 1'b1;
    endfunction

    task run();
        transaction tr;

        forever begin
            @(posedge ifc_darksocv_obj.clk);
            cycle_count++;

            if (ifc_darksocv_obj.reset == 1'b1) begin
                if ((cycle_count <= 3) || (cycle_count % 5 == 0)) begin
                    $display("[MONITOR] DUT en reset, ciclo=%0d, tiempo=%0t",
                             cycle_count, $time);
                end
            end else begin
                if (last_reset == 1'b1) begin
                    $display("[MONITOR] reset liberado en tiempo=%0t", $time);
                end

                if ((last_core_reset == 1'b1) &&
                    (ifc_darksocv_obj.core_reset == 1'b0)) begin
                    $display("[MONITOR] core darkriscv salio de reset en tiempo=%0t", $time);
                end

                if (ifc_darksocv_obj.reg_write == 1'b1) begin
                    tr = new();

                    tr.cycle     = cycle_count;
                    tr.pc        = ifc_darksocv_obj.pc;
                    tr.instr     = ifc_darksocv_obj.instr;
                    tr.rd        = ifc_darksocv_obj.rd;
                    tr.wdata     = ifc_darksocv_obj.wdata;
                    tr.reg_write = ifc_darksocv_obj.reg_write;
                    tr.hlt       = ifc_darksocv_obj.hlt;
                    tr.debug     = ifc_darksocv_obj.debug;

                    tr.print("MONITOR");
                    mon2scb.put(tr);
                end
            end

            last_pc = ifc_darksocv_obj.pc;
            last_instr = ifc_darksocv_obj.instr;
            last_reset = ifc_darksocv_obj.reset;
            last_core_reset = ifc_darksocv_obj.core_reset;
        end
    endtask

endclass

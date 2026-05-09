// Monitor pasivo del proyecto darksocv/darkriscv.
// Observa senales utiles del DUT para futuras etapas de scoreboard y checker.
class monitor;
    virtual ifc_darksocv ifc_darksocv_obj;

    int cycle_count;
    logic [31:0] last_pc;
    logic [31:0] last_instr;
    logic        last_reset;
    logic        last_core_reset;

    function new(virtual ifc_darksocv ifc_darksocv_obj);
        this.ifc_darksocv_obj = ifc_darksocv_obj;
        cycle_count = 0;
        last_pc = 32'hFFFF_FFFF;
        last_instr = 32'hFFFF_FFFF;
        last_reset = 1'b1;
        last_core_reset = 1'b1;
    endfunction

    task run();
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

                if ((last_core_reset == 1'b1) && (ifc_darksocv_obj.core_reset == 1'b0)) begin
                    $display("[MONITOR] core darkriscv salio de reset en tiempo=%0t", $time);
                end

                // Imprime preferiblemente cuando hay escritura al banco de registros.
                if (ifc_darksocv_obj.reg_write == 1'b1) begin
                    $display("[MONITOR] ciclo=%0d PC=%08h INSTR=%08h RD=x%0d WDATA=%08h WE=%0b HLT=%0b DBG=%0b",
                             cycle_count,
                             ifc_darksocv_obj.pc,
                             ifc_darksocv_obj.instr,
                             ifc_darksocv_obj.rd,
                             ifc_darksocv_obj.wdata,
                             ifc_darksocv_obj.reg_write,
                             ifc_darksocv_obj.hlt,
                             ifc_darksocv_obj.debug);
                end
                // Si no hubo writeback, reporta cambios relevantes de manera controlada.
                else if ((ifc_darksocv_obj.pc != last_pc) ||
                         (ifc_darksocv_obj.instr != last_instr)) begin
                    if ((ifc_darksocv_obj.instr == 32'h0000006F) ||
                        (cycle_count % 8 == 0)) begin
                        $display("[MONITOR] ciclo=%0d PC=%08h INSTR=%08h WE=%0b HLT=%0b DBG=%0b",
                                 cycle_count,
                                 ifc_darksocv_obj.pc,
                                 ifc_darksocv_obj.instr,
                                 ifc_darksocv_obj.reg_write,
                                 ifc_darksocv_obj.hlt,
                                 ifc_darksocv_obj.debug);
                    end
                end
            end

            last_pc = ifc_darksocv_obj.pc;
            last_instr = ifc_darksocv_obj.instr;
            last_reset = ifc_darksocv_obj.reset;
            last_core_reset = ifc_darksocv_obj.core_reset;
        end
    endtask
endclass

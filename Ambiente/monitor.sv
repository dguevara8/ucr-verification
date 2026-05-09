class monitor;

    virtual ifc_darksocv ifc;
    scoreboard scoreboard_obj;

    logic [3:0] last_led;
    logic [3:0] last_debug;

    function new(virtual ifc_darksocv ifc,
                 scoreboard scoreboard_obj);

        this.ifc = ifc;
        this.scoreboard_obj = scoreboard_obj;

        last_led   = 0;
        last_debug = 0;
    endfunction

    task check();
        forever begin
            @(posedge ifc.clk);

            if (ifc.reset == 0) begin

                // EVENTO: CAMBIO EN DEBUG
                if (ifc.debug != last_debug) begin

                    $display("[MONITOR] DEBUG cambió %0h -> %0h @%0t",
                             last_debug, ifc.debug, $time);

                    scoreboard_obj.compare_debug(ifc.debug);

                end

                // EVENTO: CAMBIO EN LED
                if (ifc.led != last_led) begin

                    $display("[MONITOR] LED cambió %0h -> %0h @%0t",
                             last_led, ifc.led, $time);

                    scoreboard_obj.compare_led(ifc.led);

                end

                last_debug = ifc.debug;
                last_led   = ifc.led;

            end
        end
    endtask

endclass
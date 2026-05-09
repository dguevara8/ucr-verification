class env;

    virtual ifc_darksocv ifc_darksocv_obj;

    driver driver_obj;
    monitor monitor_obj;
    scoreboard scoreboard_obj;

    mailbox #(transaction) mon2scb;

    function new(virtual ifc_darksocv ifc_darksocv_obj);
        $display("Ambiente: metodo creador del ambiente");

        this.ifc_darksocv_obj = ifc_darksocv_obj;

        mon2scb = new();

        driver_obj = new(ifc_darksocv_obj);
        monitor_obj = new(ifc_darksocv_obj, mon2scb);
        scoreboard_obj = new(mon2scb);
    endfunction

    task run();
        fork
            driver_obj.run();
            monitor_obj.run();
            scoreboard_obj.run();
        join_none
    endtask

    function void report();
        scoreboard_obj.report();
    endfunction

endclass
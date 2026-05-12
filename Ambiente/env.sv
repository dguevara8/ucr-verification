class env;

    virtual ifc_darksocv ifc_darksocv_obj;

    driver driver_obj;
    monitor monitor_obj;
    scoreboard scoreboard_obj;
    riscv_checker checker_obj;

    mailbox #(transaction) mon2chk;

    function new(virtual ifc_darksocv ifc_darksocv_obj);

        $display("Ambiente: metodo creador del ambiente");

        this.ifc_darksocv_obj = ifc_darksocv_obj;

        mon2chk = new();

        driver_obj = new(ifc_darksocv_obj);
        monitor_obj = new(ifc_darksocv_obj, mon2chk);
        scoreboard_obj = new();
        checker_obj = new(mon2chk, scoreboard_obj);

    endfunction

    task run();
        fork
            driver_obj.run();
            monitor_obj.run();
            checker_obj.run();
        join_none
    endtask

    function void report();
        checker_obj.report();
    endfunction

endclass


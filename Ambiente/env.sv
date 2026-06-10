class env;

    virtual ifc_darksocv ifc_darksocv_obj;

    driver driver_obj;
    instruction_monitor instruction_monitor_obj;
    monitor monitor_obj;
    scoreboard scoreboard_obj;
    riscv_checker checker_obj;

    mailbox #(transaction) drv2imon;
    mailbox #(transaction) imon2scb;
    mailbox #(transaction) scb2chk;
    mailbox #(transaction) mon2chk;

    function new(virtual ifc_darksocv ifc_darksocv_obj);

        $display("Ambiente: metodo creador del ambiente");

        this.ifc_darksocv_obj = ifc_darksocv_obj;

        drv2imon = new();
        imon2scb = new();
        scb2chk = new();
        mon2chk = new();

        driver_obj = new(ifc_darksocv_obj, drv2imon);
        instruction_monitor_obj = new(drv2imon, imon2scb);
        monitor_obj = new(ifc_darksocv_obj, mon2chk);
        scoreboard_obj = new(imon2scb, scb2chk);
        checker_obj = new(mon2chk, scb2chk);

    endfunction

    task run();
        fork
            driver_obj.run();
            instruction_monitor_obj.run();
            scoreboard_obj.run();
            monitor_obj.run();
            checker_obj.run();
        join_none
    endtask

    function void report();
        checker_obj.report();
    endfunction

endclass

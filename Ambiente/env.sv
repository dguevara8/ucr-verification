class env;

    virtual ifc_darksocv ifc;

    driver driver_obj;
    monitor monitor_obj;
    scoreboard scoreboard_obj;

    function new(virtual ifc_darksocv ifc);

        this.ifc = ifc;

        scoreboard_obj = new(); 
        driver_obj     = new(ifc);
        monitor_obj    = new(ifc, scoreboard_obj);

    endfunction

    task run();
        fork
            driver_obj.run();
            monitor_obj.check();
        join_none
    endtask

endclass
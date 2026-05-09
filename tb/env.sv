// Ambiente minimo: contiene el driver.
class env;
    virtual ifc_darksocv ifc_darksocv_obj;
    driver driver_obj;
    monitor monitor_obj;

    function new(virtual ifc_darksocv ifc_darksocv_obj);
        $display("Ambiente: metodo creador del ambiente");
        this.ifc_darksocv_obj = ifc_darksocv_obj;
        driver_obj = new(ifc_darksocv_obj);
        monitor_obj = new(ifc_darksocv_obj);
    endfunction

    // Ejecuta driver y monitor en paralelo.
    task run();
        fork
            driver_obj.run();
            monitor_obj.run();
        join_none
    endtask
endclass

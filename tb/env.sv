// Ambiente minimo: contiene el driver.
class env;
    virtual ifc_darksocv ifc_darksocv_obj;
    driver driver_obj;

    function new(virtual ifc_darksocv ifc_darksocv_obj);
        $display("Ambiente: metodo creador del ambiente");
        this.ifc_darksocv_obj = ifc_darksocv_obj;
        driver_obj = new(ifc_darksocv_obj);
    endfunction
endclass

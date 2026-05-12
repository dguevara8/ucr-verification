// Test principal del avance #1.
program testcase(ifc_darksocv ifc_darksocv_obj);
    env env_obj = new(ifc_darksocv_obj);

    // Secuencia del test: usa el driver para crear y cargar el programa.
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        env_obj.run();

        // Tiempo de observacion extendido para permitir que el core interno
        // salga de reset y ejecute varias instrucciones antes de finalizar.
        repeat (1000) @(posedge ifc_darksocv_obj.clk);
        $display("[TEST] Fin de la simulacion");
        $finish;
    end
endprogram
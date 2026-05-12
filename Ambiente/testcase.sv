program testcase(ifc_darksocv ifc_darksocv_obj);

    env env_obj;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0);

        env_obj = new(ifc_darksocv_obj);
        env_obj.run();

        repeat (2000) @(posedge ifc_darksocv_obj.clk);

      	$display("[TEST] Fin de la simulacion");
        $finish;
    end

endprogram
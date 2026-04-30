class driver;

    stimulus    stimulus_obj;
    scoreboard  scoreboard_obj;
    virtual     ifc_ram ifc_ram_obj;

    function new (virtual ifc_ram ifc_ram_obj, scoreboard scoreboard_obj);
        this.ifc_ram_obj = ifc_ram_obj;
        this.scoreboard_obj = scoreboard_obj;
    endfunction

    task reset();
        $display("Driver: Reset sequence");
        ifc_ram_obj.reset       = 1;
        ifc_ram_obj.wr_data     = '0;
        ifc_ram_obj.wr_en       = '0;
        ifc_ram_obj.wr_addr     = '0;
        //ifc_ram_obj.rd_data     = '0;
        ifc_ram_obj.rd_en       = '0;
        ifc_ram_obj.rd_addr     = '0;
        @(posedge ifc_ram_obj.clk);
        repeat (50) @(posedge ifc_ram_obj.clk);
        ifc_ram_obj.reset = 0;
    endtask

    task write_random_data();
        $display("Driver: Creando nueva palabra para ser escrita");
        stimulus_obj = new();
        stimulus_obj.randomize();
        $display("Driver: Inicio del protocolo de escritura aleatoria");
        ifc_ram_obj.wr_data     = '0;
        ifc_ram_obj.wr_en       = '0;
        //ifc_ram_obj.wr_addr     = '0;
        @(posedge ifc_ram_obj.clk);
        ifc_ram_obj.wr_data     = stimulus_obj.word;
        ifc_ram_obj.wr_en       = 1;
        ifc_ram_obj.wr_addr     = stimulus_obj.wr_addr;
        @(posedge ifc_ram_obj.clk);
        ifc_ram_obj.wr_data     = '0;
        ifc_ram_obj.wr_en       = '0;        
    endtask

    task write_data(int wr_addr = 0);
        $display("Driver: Creando nueva palabra para ser escrita");
        stimulus_obj = new();
        stimulus_obj.randomize();
        $display("Driver DEBUG: palabra generada = %d", wr_addr);
        $display("Driver: Inicio del protocolo de escritura\n");
        ifc_ram_obj.wr_data     = '0;
        ifc_ram_obj.wr_en       = '0;
        //ifc_ram_obj.wr_addr     = '0;
        @(posedge ifc_ram_obj.clk);
        ifc_ram_obj.wr_data     = wr_addr;
        ifc_ram_obj.wr_en       = 1;
        ifc_ram_obj.wr_addr     = wr_addr;
        scoreboard_obj.SIM_MEMORY[wr_addr] = wr_addr;
        @(posedge ifc_ram_obj.clk);
        ifc_ram_obj.wr_data     = '0;
        ifc_ram_obj.wr_en       = '0;        
    endtask  

    task read_random_data();
        $display("Driver: Inicio del protocolo de lectura aleatoria");
        stimulus_obj = new();
        stimulus_obj.randomize();
        ifc_ram_obj.rd_en       = '0;
        ifc_ram_obj.rd_addr     = '0;
        @(posedge ifc_ram_obj.clk);
        ifc_ram_obj.rd_en       = 1;
        ifc_ram_obj.rd_addr     = stimulus_obj.rd_addr;
        @(posedge ifc_ram_obj.clk);
        ifc_ram_obj.rd_en       = '0;
        ifc_ram_obj.rd_addr     = '0;
    endtask

    task read_data(int rd_addr = 0);
        $display("Driver: Inicio del protocolo de lectura específica");
        stimulus_obj = new();
        stimulus_obj.randomize();
        ifc_ram_obj.rd_en       = '0;
        ifc_ram_obj.rd_addr     = '0;
        @(posedge ifc_ram_obj.clk);
        ifc_ram_obj.rd_en       = 1;
        ifc_ram_obj.rd_addr     = rd_addr;
        @(posedge ifc_ram_obj.clk);
        ifc_ram_obj.rd_en       = '0;
        ifc_ram_obj.rd_addr     = '0;
    endtask    

endclass
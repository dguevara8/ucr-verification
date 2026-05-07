module top ();

    logic clk;
    logic reset;

    initial begin
        clk = 0;
        forever begin
            #1 clk = ~clk;
        end
    end

    ifc_ram ifc_ram_obj(clk);
  
    // Instanciación del DUT
    flip_flop_ram dut (
        .clk       (clk),
        .reset     (ifc_ram_obj.reset),
        .wr_data   (ifc_ram_obj.wr_data),
        .wr_en     (ifc_ram_obj.wr_en),
        .wr_addr   (ifc_ram_obj.wr_addr),
        .rd_data   (ifc_ram_obj.rd_data),
        .rd_en     (ifc_ram_obj.rd_en),
        .rd_addr   (ifc_ram_obj.rd_addr)
    );

    //Test case
    testcase test(ifc_ram_obj);

    //testcase test(ifc_ram_obj);
endmodule
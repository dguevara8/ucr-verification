module top();
    logic clk;

    wire uart_tx;
    wire uart_rx;
    wire [3:0] led;
    wire [3:0] debug;

    assign uart_rx = 1'b1;

    initial begin
        clk = 1'b0;
        forever begin
            #5 clk = ~clk;
        end
    end
  
  	initial begin
    	ifc_darksocv_obj.reset = 1;
    	#20;
    	ifc_darksocv_obj.reset = 0;
	end

    ifc_darksocv ifc_darksocv_obj(clk);

    // DUT principal del proyecto.
    darksocv dut(
        .XCLK(clk),
        .XRES(ifc_darksocv_obj.reset),
        .UART_RXD(uart_rx),
        .UART_TXD(uart_tx),
        .LED(led),
        .DEBUG(debug)
    );
  
  	assign ifc_darksocv_obj.uart_rx = uart_rx;
	assign ifc_darksocv_obj.uart_tx = uart_tx;
	assign ifc_darksocv_obj.led     = led;
	assign ifc_darksocv_obj.debug   = debug;

    // Test case.
    testcase test(ifc_darksocv_obj);
endmodule

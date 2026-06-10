class riscv_checker;

    mailbox #(transaction) mon2chk;
    mailbox #(transaction) scb2chk;

    int pass_count;
    int fail_count;

    function new(mailbox #(transaction) mon2chk,
                 mailbox #(transaction) scb2chk);
        this.mon2chk = mon2chk;
        this.scb2chk = scb2chk;

        pass_count = 0;
        fail_count = 0;
    endfunction

    function string get_op_name(logic [31:0] instr);

        logic [6:0] opcode;
        logic [6:0] funct7;
        logic [2:0] funct3;

        opcode = instr[6:0];
        funct3 = instr[14:12];
        funct7 = instr[31:25];

        case (opcode)
            7'b0010011: begin
                case (funct3)
                    3'b000: return "ADDI";
                    3'b010: return "SLTI";
                    3'b011: return "SLTIU";
                    3'b100: return "XORI";
                    3'b110: return "ORI";
                    3'b111: return "ANDI";
                    3'b001: return (funct7 == 7'b0000000) ? "SLLI" : "UNKNOWN";
                    3'b101: begin
                        if (funct7 == 7'b0000000) return "SRLI";
                        else if (funct7 == 7'b0100000) return "SRAI";
                        else return "UNKNOWN";
                    end
                    default: return "UNKNOWN";
                endcase
            end

            7'b0110011: begin
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: return "ADD";
                    {7'b0100000, 3'b000}: return "SUB";
                    {7'b0000000, 3'b001}: return "SLL";
                    {7'b0000000, 3'b010}: return "SLT";
                    {7'b0000000, 3'b011}: return "SLTU";
                    {7'b0000000, 3'b100}: return "XOR";
                    {7'b0000000, 3'b101}: return "SRL";
                    {7'b0100000, 3'b101}: return "SRA";
                    {7'b0000000, 3'b110}: return "OR";
                    {7'b0000000, 3'b111}: return "AND";
                    default: return "UNKNOWN";
                endcase
            end

            default: return "UNKNOWN";
        endcase

    endfunction

    task run();

        transaction actual_tr;
        transaction expected_tr;
        string op_name;

        forever begin
            scb2chk.get(expected_tr);
            mon2chk.get(actual_tr);

            op_name = get_op_name(expected_tr.instr);

            if (actual_tr.pc !== expected_tr.pc) begin
                $error("[CHECKER][FAIL] OP=%s DUT_PC=%08h EXPECTED_PC=%08h -> PC INCORRECTO",
                       op_name,
                       actual_tr.pc,
                       expected_tr.pc);
                fail_count++;
            end
            else if (actual_tr.rd !== expected_tr.rd) begin
                $error("[CHECKER][FAIL] OP=%s PC=%08h DUT_RD=x%0d EXPECTED_RD=x%0d -> REGISTRO DESTINO INCORRECTO",
                       op_name,
                       actual_tr.pc,
                       actual_tr.rd,
                       expected_tr.rd);
                fail_count++;
            end
            else if (actual_tr.wdata !== expected_tr.wdata) begin
                $error("[CHECKER][FAIL] OP=%s PC=%08h RD=x%0d DUT=%0d EXPECTED=%0d -> INCORRECTO",
                       op_name,
                       actual_tr.pc,
                       actual_tr.rd,
                       $signed(actual_tr.wdata),
                       $signed(expected_tr.wdata));
                fail_count++;
            end
            else begin
                $display("[CHECKER][PASS] OP=%s PC=%08h RD=x%0d DUT=%0d EXPECTED=%0d -> CORRECTO",
                         op_name,
                         actual_tr.pc,
                         actual_tr.rd,
                         $signed(actual_tr.wdata),
                         $signed(expected_tr.wdata));
                pass_count++;
            end
        end

    endtask

    function void report();
        $display("\n================ CHECKER REPORT ================");
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);
        $display("================================================\n");
    endfunction

endclass

module darksocv_checkers(ifc_darksocv ifc_darksocv_obj);

    property no_unknown_control;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset)
        !$isunknown({
            ifc_darksocv_obj.pc,
            ifc_darksocv_obj.instr,
            ifc_darksocv_obj.rd,
            ifc_darksocv_obj.wdata,
            ifc_darksocv_obj.reg_write,
            ifc_darksocv_obj.hlt,
            ifc_darksocv_obj.debug
        });
    endproperty

    assert property (no_unknown_control)
        else $error("[CHECKER_ASSERT] Hay X/Z en senales observadas del DUT");

    property pc_aligned;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset)
        ifc_darksocv_obj.pc[1:0] == 2'b00;
    endproperty

    assert property (pc_aligned)
        else $error("[CHECKER_ASSERT] PC no alineado: %08h", ifc_darksocv_obj.pc);

    property no_write_x0;
        @(posedge ifc_darksocv_obj.clk)
        disable iff (ifc_darksocv_obj.reset || ifc_darksocv_obj.core_reset)
        ifc_darksocv_obj.reg_write |-> (ifc_darksocv_obj.rd != 5'd0);
    endproperty

    assert property (no_write_x0)
        else $error("[CHECKER_ASSERT] Escritura invalida a x0");

endmodule
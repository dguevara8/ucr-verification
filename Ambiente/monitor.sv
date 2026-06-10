class monitor;

    virtual ifc_darksocv ifc_darksocv_obj;
    mailbox #(transaction) mon2scb;

    int cycle_count;
    logic [31:0] last_pc;
    logic [31:0] last_instr;
    logic        last_reset;
    logic        last_core_reset;

    function new(virtual ifc_darksocv ifc_darksocv_obj,
                 mailbox #(transaction) mon2scb);
        this.ifc_darksocv_obj = ifc_darksocv_obj;
        this.mon2scb = mon2scb;

        cycle_count = 0;
        last_pc = 32'hFFFF_FFFF;
        last_instr = 32'hFFFF_FFFF;
        last_reset = 1'b1;
        last_core_reset = 1'b1;
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

                    3'b001: begin
                      if (funct7 == 7'b0000000) return "SLLI";
                        else return "UNKNOWN";
                    end

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

    function bit instr_has_rd(logic [31:0] instr);

        logic [6:0] opcode;

        opcode = instr[6:0];

        case (opcode)
            7'b0010011: return 1'b1; // ADDI
            7'b0110011: return 1'b1; // Tipo R
            default:    return 1'b0;
        endcase

    endfunction

    function logic [4:0] get_instr_rd(logic [31:0] instr);
        return instr[11:7];
    endfunction

    task run();
        transaction tr;

        forever begin
            @(posedge ifc_darksocv_obj.clk);
            cycle_count++;

            if (ifc_darksocv_obj.reset == 1'b1) begin
                if ((cycle_count <= 3) || (cycle_count % 5 == 0)) begin
                    $display("[MONITOR] DUT en reset, ciclo=%0d, tiempo=%0t",
                             cycle_count, $time);
                end
            end else begin
                if (last_reset == 1'b1) begin
                    $display("[MONITOR] reset liberado en tiempo=%0t", $time);
                end

                if ((last_core_reset == 1'b1) &&
                    (ifc_darksocv_obj.core_reset == 1'b0)) begin
                    $display("[MONITOR] core darkriscv salio de reset en tiempo=%0t", $time);
                end

                if (ifc_darksocv_obj.reg_write == 1'b1) begin
                    tr = new();

                    tr.cycle     = cycle_count;
                    tr.pc        = ifc_darksocv_obj.pc;
                    tr.instr     = ifc_darksocv_obj.instr;
                    tr.rd        = ifc_darksocv_obj.rd;
                    tr.wdata     = ifc_darksocv_obj.wdata;
                    tr.reg_write = ifc_darksocv_obj.reg_write;
                    tr.hlt       = ifc_darksocv_obj.hlt;
                    tr.debug     = ifc_darksocv_obj.debug;

                    $display("[MONITOR] OBSERVADO ciclo=%0d PC=%08h INSTR=%08h OP=%s RD=x%0d DUT_WDATA=%0d WE=%0b HLT=%0b DBG=%0b",
                             cycle_count,
                             ifc_darksocv_obj.pc,
                             ifc_darksocv_obj.instr,
                             get_op_name(ifc_darksocv_obj.instr),
                             ifc_darksocv_obj.rd,
                             $signed(ifc_darksocv_obj.wdata),
                             ifc_darksocv_obj.reg_write,
                             ifc_darksocv_obj.hlt,
                             ifc_darksocv_obj.debug);

                    mon2scb.put(tr);
                end
                else if (instr_has_rd(ifc_darksocv_obj.instr) &&
                         (get_instr_rd(ifc_darksocv_obj.instr) == 5'd0)) begin
                    $display("[MONITOR] OBSERVADO ciclo=%0d PC=%08h INSTR=%08h OP=%s RD=x0 WE=%0b -> rd=0; x0 no genera escritura arquitectonica",
                             cycle_count,
                             ifc_darksocv_obj.pc,
                             ifc_darksocv_obj.instr,
                             get_op_name(ifc_darksocv_obj.instr),
                             ifc_darksocv_obj.reg_write);
                end
            end

            last_pc = ifc_darksocv_obj.pc;
            last_instr = ifc_darksocv_obj.instr;
            last_reset = ifc_darksocv_obj.reset;
            last_core_reset = ifc_darksocv_obj.core_reset;
        end
    endtask

endclass
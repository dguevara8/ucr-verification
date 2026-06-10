// Monitor antes del DUT.
// Recibe del driver las instrucciones generadas y las envia al scoreboard.
class instruction_monitor;

    mailbox #(transaction) drv2imon;
    mailbox #(transaction) imon2scb;

    function new(mailbox #(transaction) drv2imon,
                 mailbox #(transaction) imon2scb);
        this.drv2imon = drv2imon;
        this.imon2scb = imon2scb;
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

        transaction tr;

        forever begin
            drv2imon.get(tr);

            $display("[INSTR_MONITOR] PRE_DUT PC=%08h INSTR=%08h OP=%s RD=x%0d",
                     tr.pc,
                     tr.instr,
                     get_op_name(tr.instr),
                     tr.rd);

            imon2scb.put(tr);
        end

    endtask

endclass
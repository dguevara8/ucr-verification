class scoreboard;

    mailbox #(transaction) mon2scb;

    logic [31:0] reg_model [32];

    int pass_count;
    int fail_count;

    function new(mailbox #(transaction) mon2scb);
        this.mon2scb = mon2scb;

        foreach (reg_model[i]) begin
            reg_model[i] = 32'h00000000;
        end

        pass_count = 0;
        fail_count = 0;
    endfunction

    task run();
        transaction tr;

        forever begin
            mon2scb.get(tr);
            check_transaction(tr);
        end
    endtask

    task check_transaction(transaction tr);

        logic [6:0] opcode;
        logic [6:0] funct7;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [4:0] rs1;
        logic [4:0] rs2;
        logic signed [31:0] s_rs1;

        logic [31:0] rs1_val;
        logic [31:0] rs2_val;
        logic [31:0] expected;
        logic [31:0] imm_i;

        bit valid_instr;

        opcode = tr.instr[6:0];
        rd     = tr.instr[11:7];
        funct3 = tr.instr[14:12];
        rs1    = tr.instr[19:15];
        rs2    = tr.instr[24:20];
        funct7 = tr.instr[31:25];

        rs1_val = reg_model[rs1];
        rs2_val = reg_model[rs2];
        s_rs1   = rs1_val;

        expected = 32'h00000000;
        valid_instr = 1'b1;

        case (opcode)

            7'b0010011: begin
                // ADDI
                imm_i = {{20{tr.instr[31]}}, tr.instr[31:20]};

                case (funct3)
                    3'b000: expected = rs1_val + imm_i;
                    default: valid_instr = 1'b0;
                endcase
            end

            7'b0110011: begin
                // Tipo R
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: expected = rs1_val + rs2_val;                  // ADD
                    {7'b0100000, 3'b000}: expected = rs1_val - rs2_val;                  // SUB
                    {7'b0000000, 3'b001}: expected = rs1_val << rs2_val[4:0];            // SLL
                    {7'b0000000, 3'b010}: expected = ($signed(rs1_val) < $signed(rs2_val)) ? 32'd1 : 32'd0; // SLT
                    {7'b0000000, 3'b011}: expected = (rs1_val < rs2_val) ? 32'd1 : 32'd0; // SLTU
                    {7'b0000000, 3'b100}: expected = rs1_val ^ rs2_val;                  // XOR
                    {7'b0000000, 3'b101}: expected = rs1_val >> rs2_val[4:0];            // SRL
                    {7'b0100000, 3'b101}: expected = s_rs1 >>> rs2_val[4:0];             // SRA
                    {7'b0000000, 3'b110}: expected = rs1_val | rs2_val;                  // OR
                    {7'b0000000, 3'b111}: expected = rs1_val & rs2_val;                  // AND
                    default: valid_instr = 1'b0;
                endcase
            end

            default: begin
                valid_instr = 1'b0;
            end

        endcase

        if (!valid_instr) begin
            $error("[SCOREBOARD] Instruccion no soportada. PC=%08h INSTR=%08h",
                   tr.pc, tr.instr);
            fail_count++;
            return;
        end

        if (tr.rd !== rd) begin
            $error("[SCOREBOARD] RD incorrecto. PC=%08h INSTR=%08h DUT_RD=x%0d EXPECTED_RD=x%0d",
                   tr.pc, tr.instr, tr.rd, rd);
            fail_count++;
        end else if (tr.wdata !== expected) begin
            $error("[SCOREBOARD] DATO incorrecto. PC=%08h INSTR=%08h RD=x%0d DUT=%08h ESPERADO=%08h",
                   tr.pc, tr.instr, tr.rd, tr.wdata, expected);
            fail_count++;
        end else begin
            $display("[SCOREBOARD] PASS PC=%08h INSTR=%08h x%0d=%08h",
                     tr.pc, tr.instr, tr.rd, tr.wdata);
            pass_count++;
        end

        if (rd != 5'd0) begin
            reg_model[rd] = expected;
        end

        reg_model[0] = 32'h00000000;

    endtask

    function void report();
        $display("\n================ SCOREBOARD REPORT ================");
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);
        $display("==================================================\n");
    endfunction

endclass
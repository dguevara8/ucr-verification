class scoreboard;
  
  	mailbox #(transaction) imon2scb;
    mailbox #(transaction) scb2chk;

    logic [31:0] reg_model [32];

    logic [4:0]  expected_rd;
    logic [31:0] expected_wdata;
    bit          expected_valid;

    string       expected_op;
    logic [4:0]  expected_rs1;
    logic [4:0]  expected_rs2;
    logic [31:0] expected_rs1_val;
    logic [31:0] expected_rs2_val;
    logic [31:0] expected_imm;
    bit          expected_uses_imm;

  function new(mailbox #(transaction) imon2scb,
                 mailbox #(transaction) scb2chk);
        this.imon2scb = imon2scb;
        this.scb2chk = scb2chk;
      
        foreach (reg_model[i]) begin
            reg_model[i] = 32'h00000000;
        end

        expected_rd = 5'd0;
        expected_wdata = 32'h00000000;
        expected_valid = 1'b0;

        expected_op = "UNKNOWN";
        expected_rs1 = 5'd0;
        expected_rs2 = 5'd0;
        expected_rs1_val = 32'h00000000;
        expected_rs2_val = 32'h00000000;
        expected_imm = 32'h00000000;
        expected_uses_imm = 1'b0;
    endfunction
  
  	task run();

        transaction instr_tr;
        transaction expected_tr;

        forever begin
            imon2scb.get(instr_tr);

            calculate_expected(instr_tr);

            if (expected_valid && (expected_rd != 5'd0)) begin
                expected_tr = new();

                expected_tr.cycle = instr_tr.cycle;
                expected_tr.pc = instr_tr.pc;
                expected_tr.instr = instr_tr.instr;
                expected_tr.rd = expected_rd;
                expected_tr.wdata = expected_wdata;
                expected_tr.reg_write = 1'b1;
                expected_tr.hlt = 1'b0;
                expected_tr.debug = 4'h0;

                scb2chk.put(expected_tr);
            end
            else if (expected_valid && (expected_rd == 5'd0)) begin
                $display("[SCOREBOARD] OP=%s RD=x0 -> modelo mantiene x0=0, no se envia writeback esperado al checker",
                         expected_op);
            end
        end

    endtask

    function void calculate_expected(transaction tr);

        logic [6:0] opcode;
        logic [6:0] funct7;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [4:0] rs1;
        logic [4:0] rs2;

        logic [31:0] rs1_val;
        logic [31:0] rs2_val;
        logic [31:0] imm_i;
        logic signed [31:0] s_rs1;

        opcode = tr.instr[6:0];
        rd     = tr.instr[11:7];
        funct3 = tr.instr[14:12];
        rs1    = tr.instr[19:15];
        rs2    = tr.instr[24:20];
        funct7 = tr.instr[31:25];

        rs1_val = reg_model[rs1];
        rs2_val = reg_model[rs2];
        s_rs1   = rs1_val;

        expected_rd = rd;
        expected_wdata = 32'h00000000;
        expected_valid = 1'b1;

        expected_op = "UNKNOWN";
        expected_rs1 = rs1;
        expected_rs2 = rs2;
        expected_rs1_val = rs1_val;
        expected_rs2_val = rs2_val;
        expected_imm = 32'h00000000;
        expected_uses_imm = 1'b0;

        case (opcode)

                7'b0010011: begin
                  imm_i = {{20{tr.instr[31]}}, tr.instr[31:20]};

                case (funct3)
                    3'b000: begin
                        expected_op = "ADDI";
                        expected_uses_imm = 1'b1;
                        expected_imm = imm_i;
                        expected_wdata = rs1_val + imm_i;
                    end

                    3'b010: begin
                        expected_op = "SLTI";
                        expected_uses_imm = 1'b1;
                        expected_imm = imm_i;
                        expected_wdata = ($signed(rs1_val) < $signed(imm_i)) ? 32'd1 : 32'd0;
                    end

                    3'b011: begin
                        expected_op = "SLTIU";
                        expected_uses_imm = 1'b1;
                        expected_imm = imm_i;
                        expected_wdata = (rs1_val < imm_i) ? 32'd1 : 32'd0;
                    end

                    3'b100: begin
                        expected_op = "XORI";
                        expected_uses_imm = 1'b1;
                        expected_imm = imm_i;
                        expected_wdata = rs1_val ^ imm_i;
                    end

                    3'b110: begin
                        expected_op = "ORI";
                        expected_uses_imm = 1'b1;
                        expected_imm = imm_i;
                        expected_wdata = rs1_val | imm_i;
                    end

                    3'b111: begin
                        expected_op = "ANDI";
                        expected_uses_imm = 1'b1;
                        expected_imm = imm_i;
                        expected_wdata = rs1_val & imm_i;
                    end

                    3'b001: begin
                        if (funct7 == 7'b0000000) begin
                            expected_op = "SLLI";
                            expected_uses_imm = 1'b1;
                            expected_imm = rs2;
                            expected_wdata = rs1_val << rs2;
                        end else begin
                            expected_valid = 1'b0;
                        end
                    end

                    3'b101: begin
                        expected_uses_imm = 1'b1;
                        expected_imm = rs2;

                        if (funct7 == 7'b0000000) begin
                            expected_op = "SRLI";
                            expected_wdata = rs1_val >> rs2;
                        end else if (funct7 == 7'b0100000) begin
                            expected_op = "SRAI";
                            expected_wdata = $signed(rs1_val) >>> rs2;
                        end else begin
                            expected_valid = 1'b0;
                        end
                    end

                    default: begin
                        expected_valid = 1'b0;
                    end
                endcase
            end

            7'b0110011: begin
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: begin
                        expected_op = "ADD";
                        expected_wdata = rs1_val + rs2_val;
                    end

                    {7'b0100000, 3'b000}: begin
                        expected_op = "SUB";
                        expected_wdata = rs1_val - rs2_val;
                    end

                    {7'b0000000, 3'b001}: begin
                        expected_op = "SLL";
                        expected_wdata = rs1_val << rs2_val[4:0];
                    end

                    {7'b0000000, 3'b010}: begin
                        expected_op = "SLT";
                        expected_wdata = ($signed(rs1_val) < $signed(rs2_val)) ? 32'd1 : 32'd0;
                    end

                    {7'b0000000, 3'b011}: begin
                        expected_op = "SLTU";
                        expected_wdata = (rs1_val < rs2_val) ? 32'd1 : 32'd0;
                    end

                    {7'b0000000, 3'b100}: begin
                        expected_op = "XOR";
                        expected_wdata = rs1_val ^ rs2_val;
                    end

                    {7'b0000000, 3'b101}: begin
                        expected_op = "SRL";
                        expected_wdata = rs1_val >> rs2_val[4:0];
                    end

                    {7'b0100000, 3'b101}: begin
                        expected_op = "SRA";
                        expected_wdata = s_rs1 >>> rs2_val[4:0];
                    end

                    {7'b0000000, 3'b110}: begin
                        expected_op = "OR";
                        expected_wdata = rs1_val | rs2_val;
                    end

                    {7'b0000000, 3'b111}: begin
                        expected_op = "AND";
                        expected_wdata = rs1_val & rs2_val;
                    end

                    default: begin
                        expected_valid = 1'b0;
                    end
                endcase
            end

            default: begin
                expected_valid = 1'b0;
            end

        endcase

        if (expected_valid) begin
            if (expected_uses_imm) begin
                $display("[SCOREBOARD] OP=%s RD=x%0d RS1=x%0d(%0d) IMM=%0d EXPECTED=%0d",
                         expected_op,
                         expected_rd,
                         expected_rs1,
                         $signed(expected_rs1_val),
                         $signed(expected_imm),
                         $signed(expected_wdata));
            end else begin
                $display("[SCOREBOARD] OP=%s RD=x%0d RS1=x%0d(%0d) RS2=x%0d(%0d) EXPECTED=%0d",
                         expected_op,
                         expected_rd,
                         expected_rs1,
                         $signed(expected_rs1_val),
                         expected_rs2,
                         $signed(expected_rs2_val),
                         $signed(expected_wdata));
            end
        end else begin
            $display("[SCOREBOARD] INSTRUCCION NO SOPORTADA PC=%08h INSTR=%08h",
                     tr.pc,
                     tr.instr);
        end

        // El modelo se actualiza con el valor esperado, no con el valor del DUT.
        if (expected_valid && (rd != 5'd0)) begin
            reg_model[rd] = expected_wdata;
        end

        reg_model[0] = 32'h00000000;

    endfunction

endclass




`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class riscv_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(riscv_scoreboard)

    uvm_analysis_imp_expected #(riscv_transaction, riscv_scoreboard) expected_imp;
    uvm_analysis_imp_actual   #(riscv_transaction, riscv_scoreboard) actual_imp;

    riscv_transaction expected_q[$];

    logic [31:0] reg_model [32];
    logic [31:0] mem_model [0:255];

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

    int pass_count;
    int fail_count;
    string fail_summary[$];
    bit summary_printed;

    function new(string name = "riscv_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        expected_imp = new("expected_imp", this);
        actual_imp   = new("actual_imp", this);

        foreach (reg_model[i]) begin
            reg_model[i] = 32'h00000000;
        end

        foreach (mem_model[i]) begin
            mem_model[i] = 32'h00000000;
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

        pass_count = 0;
        fail_count = 0;
        fail_summary.delete();
        summary_printed = 1'b0;
    endfunction

    function void record_fail(string fail_msg);
        fail_count++;
        fail_summary.push_back(fail_msg);
        `uvm_error(get_type_name(), fail_msg)
    endfunction

    // Equivalente a: imon2scb.get(instr_tr)
    virtual function void write_expected(riscv_transaction instr_tr);
        riscv_transaction expected_tr;

        calculate_expected(instr_tr);

        if (expected_valid && (expected_rd != 5'd0)) begin
            expected_tr = riscv_transaction::type_id::create("expected_tr");

            expected_tr.cycle     = instr_tr.cycle;
            expected_tr.pc        = instr_tr.pc;
            expected_tr.instr     = instr_tr.instr;
            expected_tr.rd        = expected_rd;
            expected_tr.rs1       = instr_tr.rs1;
            expected_tr.rs2       = instr_tr.rs2;
            expected_tr.wdata     = expected_wdata;
            expected_tr.reg_write = 1'b1;
            expected_tr.hlt       = 1'b0;
            expected_tr.debug     = 4'h0;

            expected_q.push_back(expected_tr);
        end
        else if (expected_valid && (expected_rd == 5'd0)) begin
            `uvm_info(
                get_type_name(),
                $sformatf("OP=%s RD=x0 -> modelo mantiene x0=0, no se envia writeback esperado",
                          expected_op),
                UVM_MEDIUM
            )
        end
    endfunction

    // Equivalente a checker.run(): compara expected contra actual.
    virtual function void write_actual(riscv_transaction actual_tr);
        riscv_transaction expected_tr;
        string op_name;
        string fail_msg;

        if (expected_q.size() == 0) begin
            fail_msg = $sformatf("Writeback inesperado del DUT PC=%08h INSTR=%08h RD=x%0d WDATA=%0d",
                                 actual_tr.pc,
                                 actual_tr.instr,
                                 actual_tr.rd,
                                 $signed(actual_tr.wdata));
            record_fail(fail_msg);
            return;
        end

        expected_tr = expected_q.pop_front();
        op_name = get_op_name(expected_tr.instr);

        if (actual_tr.pc !== expected_tr.pc) begin
            fail_msg = $sformatf("FAIL OP=%s DUT_PC=%08h EXPECTED_PC=%08h -> PC INCORRECTO",
                                 op_name,
                                 actual_tr.pc,
                                 expected_tr.pc);
            record_fail(fail_msg);
        end
        else if (actual_tr.rd !== expected_tr.rd) begin
            fail_msg = $sformatf("FAIL OP=%s PC=%08h DUT_RD=x%0d EXPECTED_RD=x%0d -> REGISTRO DESTINO INCORRECTO",
                                 op_name,
                                 actual_tr.pc,
                                 actual_tr.rd,
                                 expected_tr.rd);
            record_fail(fail_msg);
        end
        else if (actual_tr.wdata !== expected_tr.wdata) begin
            fail_msg = $sformatf("FAIL OP=%s PC=%08h RD=x%0d DUT=%0d EXPECTED=%0d -> INCORRECTO",
                                 op_name,
                                 actual_tr.pc,
                                 actual_tr.rd,
                                 $signed(actual_tr.wdata),
                                 $signed(expected_tr.wdata));
            record_fail(fail_msg);
        end
        else begin
            `uvm_info(
                get_type_name(),
                $sformatf("PASS OP=%s PC=%08h RD=x%0d DUT=%0d EXPECTED=%0d -> CORRECTO",
                          op_name,
                          actual_tr.pc,
                          actual_tr.rd,
                          $signed(actual_tr.wdata),
                          $signed(expected_tr.wdata)),
                UVM_LOW
            )
            pass_count++;
        end
    endfunction

    function void calculate_expected(riscv_transaction tr);

        logic [6:0] opcode;
        logic [6:0] funct7;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [4:0] rs1;
        logic [4:0] rs2;

        logic [31:0] rs1_val;
        logic [31:0] rs2_val;
        logic [31:0] imm_i;
        logic [31:0] imm_s;
        logic [31:0] imm_b;
        logic [31:0] imm_j;
        logic [31:0] imm_u;
        logic [31:0] addr;
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

            7'b0110111: begin
                imm_u = {tr.instr[31:12], 12'h000};

                expected_op = "LUI";
                expected_uses_imm = 1'b1;
                expected_imm = imm_u;
                expected_wdata = imm_u;
            end

            7'b0010111: begin
                imm_u = {tr.instr[31:12], 12'h000};

                expected_op = "AUIPC";
                expected_uses_imm = 1'b1;
                expected_imm = imm_u;
                expected_wdata = tr.pc + imm_u;
            end

            7'b0000011: begin
                imm_i = {{20{tr.instr[31]}}, tr.instr[31:20]};
                addr = rs1_val + imm_i;

                if (funct3 == 3'b010) begin
                    expected_op = "LW";
                    expected_uses_imm = 1'b1;
                    expected_imm = imm_i;
                    expected_wdata = mem_model[addr[9:2]];
                end else begin
                    expected_valid = 1'b0;
                end
            end

            7'b0100011: begin
                imm_s = {{20{tr.instr[31]}}, tr.instr[31:25], tr.instr[11:7]};
                addr = rs1_val + imm_s;

                if (funct3 == 3'b010) begin
                    expected_op = "SW";
                    expected_valid = 1'b0;
                    mem_model[addr[9:2]] = rs2_val;
                end else begin
                    expected_valid = 1'b0;
                end
            end

            7'b1100011: begin
                imm_b = {{19{tr.instr[31]}}, tr.instr[31], tr.instr[7],
                         tr.instr[30:25], tr.instr[11:8], 1'b0};
                expected_valid = 1'b0;

                case (funct3)
                    3'b000: expected_op = "BEQ";
                    3'b001: expected_op = "BNE";
                    3'b100: expected_op = "BLT";
                    3'b101: expected_op = "BGE";
                    3'b110: expected_op = "BLTU";
                    3'b111: expected_op = "BGEU";
                    default: expected_op = "UNKNOWN";
                endcase

                expected_uses_imm = 1'b1;
                expected_imm = imm_b;
            end

            7'b1101111: begin
                imm_j = {{11{tr.instr[31]}}, tr.instr[31], tr.instr[19:12],
                         tr.instr[20], tr.instr[30:21], 1'b0};

                expected_op = "JAL";
                expected_uses_imm = 1'b1;
                expected_imm = imm_j;
                expected_wdata = tr.pc + 32'd4;
            end

            7'b1100111: begin
                imm_i = {{20{tr.instr[31]}}, tr.instr[31:20]};

                if (funct3 == 3'b000) begin
                    expected_op = "JALR";
                    expected_uses_imm = 1'b1;
                    expected_imm = imm_i;
                    expected_wdata = tr.pc + 32'd4;
                end else begin
                    expected_valid = 1'b0;
                end
            end

            default: begin
                expected_valid = 1'b0;
            end

        endcase

        if (expected_valid) begin
            if (expected_uses_imm) begin
                `uvm_info(
                    get_type_name(),
                    $sformatf("OP=%s RD=x%0d RS1=x%0d(%0d) IMM=%0d EXPECTED=%0d",
                              expected_op,
                              expected_rd,
                              expected_rs1,
                              $signed(expected_rs1_val),
                              $signed(expected_imm),
                              $signed(expected_wdata)),
                    UVM_MEDIUM
                )
            end else begin
                `uvm_info(
                    get_type_name(),
                    $sformatf("OP=%s RD=x%0d RS1=x%0d(%0d) RS2=x%0d(%0d) EXPECTED=%0d",
                              expected_op,
                              expected_rd,
                              expected_rs1,
                              $signed(expected_rs1_val),
                              expected_rs2,
                              $signed(expected_rs2_val),
                              $signed(expected_wdata)),
                    UVM_MEDIUM
                )
            end
        end else begin
            `uvm_info(
                get_type_name(),
                $sformatf("INSTRUCCION NO SOPORTADA PC=%08h INSTR=%08h",
                          tr.pc,
                          tr.instr),
                UVM_MEDIUM
            )
        end

        if (expected_valid && (rd != 5'd0)) begin
            reg_model[rd] = expected_wdata;
        end

        reg_model[0] = 32'h00000000;

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

            7'b0110111: return "LUI";
            7'b0010111: return "AUIPC";
            7'b0000011: return (funct3 == 3'b010) ? "LW" : "UNKNOWN";
            7'b0100011: return (funct3 == 3'b010) ? "SW" : "UNKNOWN";

            7'b1100011: begin
                case (funct3)
                    3'b000: return "BEQ";
                    3'b001: return "BNE";
                    3'b100: return "BLT";
                    3'b101: return "BGE";
                    3'b110: return "BLTU";
                    3'b111: return "BGEU";
                    default: return "UNKNOWN";
                endcase
            end

            7'b1101111: return "JAL";
            7'b1100111: return "JALR";

            default: return "UNKNOWN";
        endcase
    endfunction

    function void print_fail_summary(string source = "FINAL");
        if (summary_printed) begin
            return;
        end

        summary_printed = 1'b1;

        `uvm_info(get_type_name(), "================ SCOREBOARD REPORT ================", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("SOURCE: %s", source), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("PASS: %0d", pass_count), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("FAIL: %0d", fail_count), UVM_LOW)
        `uvm_info(get_type_name(), "================ FAIL SUMMARY =====================", UVM_LOW)

        if (fail_summary.size() == 0) begin
            `uvm_info(get_type_name(), "No se registraron fails funcionales.", UVM_LOW)
        end else begin
            foreach (fail_summary[i]) begin
                `uvm_info(
                    get_type_name(),
                    $sformatf("FAIL[%0d]: %s", i, fail_summary[i]),
                    UVM_LOW
                )
            end
        end

        if (expected_q.size() != 0) begin
            `uvm_warning(
                get_type_name(),
                $sformatf("Quedaron %0d resultados esperados sin comparar. Puede faltar tiempo de simulacion.",
                          expected_q.size())
            )
        end

        `uvm_info(get_type_name(), "===================================================", UVM_LOW)
    endfunction

    virtual function void report_phase(uvm_phase phase);
        print_fail_summary("UVM report_phase");
    endfunction

endclass

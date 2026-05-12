class scoreboard;

    logic [31:0] reg_model [32];

    logic [4:0]  expected_rd;
    logic [31:0] expected_wdata;
    bit          expected_valid;

    function new();
        foreach (reg_model[i]) begin
            reg_model[i] = 32'h00000000;
        end

        expected_rd = 5'd0;
        expected_wdata = 32'h00000000;
        expected_valid = 1'b0;
    endfunction

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

        case (opcode)

            7'b0010011: begin
                imm_i = {{20{tr.instr[31]}}, tr.instr[31:20]};

                case (funct3)
                    3'b000: expected_wdata = rs1_val + imm_i; // ADDI
                    default: expected_valid = 1'b0;
                endcase
            end

            7'b0110011: begin
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: expected_wdata = rs1_val + rs2_val; // ADD
                    {7'b0100000, 3'b000}: expected_wdata = rs1_val - rs2_val; // SUB
                    {7'b0000000, 3'b001}: expected_wdata = rs1_val << rs2_val[4:0]; // SLL
                    {7'b0000000, 3'b010}: expected_wdata = ($signed(rs1_val) < $signed(rs2_val)) ? 32'd1 : 32'd0; // SLT
                    {7'b0000000, 3'b011}: expected_wdata = (rs1_val < rs2_val) ? 32'd1 : 32'd0; // SLTU
                    {7'b0000000, 3'b100}: expected_wdata = rs1_val ^ rs2_val; // XOR
                    {7'b0000000, 3'b101}: expected_wdata = rs1_val >> rs2_val[4:0]; // SRL
                    {7'b0100000, 3'b101}: expected_wdata = s_rs1 >>> rs2_val[4:0]; // SRA
                    {7'b0000000, 3'b110}: expected_wdata = rs1_val | rs2_val; // OR
                    {7'b0000000, 3'b111}: expected_wdata = rs1_val & rs2_val; // AND
                    default: expected_valid = 1'b0;
                endcase
            end

            default: begin
                expected_valid = 1'b0;
            end

        endcase

        if (expected_valid) begin
            $display("[SCOREBOARD] ESPERADO PC=%08h INSTR=%08h RD=x%0d EXPECTED=%08h",
                     tr.pc,
                     tr.instr,
                     expected_rd,
                     expected_wdata);
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

class riscv_subscriber extends uvm_subscriber #(riscv_transaction);

    `uvm_component_utils(riscv_subscriber)

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [1:0] instr_format;
    logic [19:0] imm_u;
    logic       reg_write;
    logic       hlt;
    logic [3:0] debug;
    int unsigned sample_count;

    covergroup riscv_cg;
        option.per_instance = 1;

        // Instrucciones R, I y U generadas por la secuencia.
        cp_opcode: coverpoint opcode {
            bins r_type = {7'b0110011};
            bins i_type = {7'b0010011};
            bins lui    = {7'b0110111};
            bins auipc  = {7'b0010111};
        }

        // Formato decodificado a partir del opcode.
        cp_instr_format: coverpoint instr_format {
            bins r_format = {2'd0};
            bins i_format = {2'd1};
            bins u_format = {2'd2};
        }

        // Todas las variantes RV32I usadas en R e I.
        cp_funct3: coverpoint funct3 {
            bins f3_000 = {3'b000};
            bins f3_001 = {3'b001};
            bins f3_010 = {3'b010};
            bins f3_011 = {3'b011};
            bins f3_100 = {3'b100};
            bins f3_101 = {3'b101};
            bins f3_110 = {3'b110};
            bins f3_111 = {3'b111};
        }

        // Diferencia ADD/SUB y SRL/SRA.
        cp_funct7: coverpoint funct7 {
            bins f7_0000000 = {7'b0000000};
            bins f7_0100000 = {7'b0100000};
        }

        // Registros destino.
        cp_rd: coverpoint rd {
            bins rv32e_regs[] = {[5'd1:5'd15]};
        }

        // Fuente 1.
        cp_rs1: coverpoint rs1 {
            bins x0 = {5'd0};
            bins rv32e_regs[] = {[5'd1:5'd15]};
        }

        // Fuente 2.
        cp_rs2: coverpoint rs2 {
            bins x0 = {5'd0};
            bins rv32e_regs[] = {[5'd1:5'd15]};
        }

        // Inmediato superior usado por LUI/AUIPC.
        cp_imm_u: coverpoint imm_u {
            bins zero = {20'h00000};
            bins low  = {[20'h00001:20'h000ff]};
            bins mid  = {[20'h00100:20'h00fff]};
            bins high = {[20'h01000:20'hfffff]};
        }

        // Verifica writeback.
        cp_reg_write: coverpoint reg_write {
            bins write = {1'b1};
        }

        // Cruces principales. LUI/AUIPC no usan funct3/funct7 de forma semantica.
        cross_opcode_funct3 : cross cp_opcode, cp_funct3 {
            ignore_bins u_no_funct3 = binsof(cp_opcode) intersect {7'b0110111, 7'b0010111};
        }

        cross_opcode_funct7 : cross cp_opcode, cp_funct7 {
            ignore_bins u_no_funct7 = binsof(cp_opcode) intersect {7'b0110111, 7'b0010111};
        }

        cross_opcode_reg_write : cross cp_opcode, cp_reg_write;

    endgroup

    function new(string name = "riscv_subscriber", uvm_component parent = null);
        super.new(name, parent);
        riscv_cg = new();
        sample_count = 0;
    endfunction

    virtual function void write(riscv_transaction t);
        sample_count++;

        opcode    = t.instr[6:0];
        rd        = t.rd;
        rs1       = t.rs1;
        rs2       = t.rs2;
        funct3    = t.instr[14:12];
        funct7    = t.instr[31:25];
        imm_u     = t.instr[31:12];
        reg_write = t.reg_write;
        hlt       = t.hlt;
        debug     = t.debug;

        case (opcode)
            7'b0110011: instr_format = 2'd0;
            7'b0010011: instr_format = 2'd1;
            7'b0110111,
            7'b0010111: instr_format = 2'd2;
            default:    instr_format = 2'd3;
        endcase

        riscv_cg.sample();

        `uvm_info(
            get_type_name(),
            $sformatf("SUBSCRIBER_SAMPLE count=%0d PC=%08h INSTR=%08h opcode=%07b format=%0d funct3=%03b funct7=%07b imm_u=%05h rd=x%0d rs1=x%0d rs2=x%0d WE=%0b HLT=%0b coverage=%0.2f%%",
                      sample_count,
                      t.pc,
                      t.instr,
                      opcode,
                      instr_format,
                      funct3,
                      funct7,
                      imm_u,
                      rd,
                      rs1,
                      rs2,
                      reg_write,
                      hlt,
                      riscv_cg.get_inst_coverage()),
            UVM_LOW
        )
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(
            get_type_name(),
            $sformatf("Functional coverage: %0.2f%% samples=%0d",
                      riscv_cg.get_coverage(),
                      sample_count),
            UVM_LOW
        )
    endfunction

endclass

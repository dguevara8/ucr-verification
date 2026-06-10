class riscv_subscriber extends uvm_subscriber #(riscv_transaction);

    `uvm_component_utils(riscv_subscriber)

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic       reg_write;
    logic       hlt;
    logic [3:0] debug;
    int unsigned sample_count;

    covergroup riscv_cg;
        option.per_instance = 1;

        // Tipo general de instruccion observado en writeback.
        cp_opcode: coverpoint opcode {
            bins r_type = {7'b0110011};
            bins i_type = {7'b0010011};
            bins lui    = {7'b0110111};
            bins auipc  = {7'b0010111};
            bins other  = default;
        }

        // Campo funct3 distingue operaciones dentro de tipo R/I.
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

        // Campo funct7 separa ADD/SUB y SRL/SRA, ademas de shifts I.
        cp_funct7: coverpoint funct7 {
            bins f7_0000000 = {7'b0000000};
            bins f7_0100000 = {7'b0100000};
            bins other      = default;
        }

        // Registros RV32E usados como destino.
        cp_rd: coverpoint rd {
            bins x0 = {5'd0};
            bins rv32e_regs[] = {[5'd1:5'd15]};
            bins rv32i_upper[] = {[5'd16:5'd31]};
        }

        // Registros RV32E usados como fuente 1.
        cp_rs1: coverpoint rs1 {
            bins x0 = {5'd0};
            bins rv32e_regs[] = {[5'd1:5'd15]};
            bins rv32i_upper[] = {[5'd16:5'd31]};
        }

        // Registros RV32E usados como fuente 2 o shamt codificado.
        cp_rs2: coverpoint rs2 {
            bins x0 = {5'd0};
            bins rv32e_regs[] = {[5'd1:5'd15]};
            bins rv32i_upper[] = {[5'd16:5'd31]};
        }

        // Confirma que el monitor esta muestreando writebacks reales.
        cp_reg_write: coverpoint reg_write {
            bins no_write = {1'b0};
            bins write    = {1'b1};
        }

        // Estado de halt observado junto con el writeback.
        cp_hlt: coverpoint hlt {
            bins running = {1'b0};
            bins halted  = {1'b1};
        }

        // Bits de debug expuestos por darkriscv/darksocv.
        cp_debug: coverpoint debug {
            bins values[] = {[4'h0:4'hF]};
        }

        // Cruces funcionales principales para instrucciones observadas.
        cross_opcode_rd: cross cp_opcode, cp_rd;
        cross_opcode_funct3: cross cp_opcode, cp_funct3;
        cross_opcode_reg_write: cross cp_opcode, cp_reg_write;
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
        reg_write = t.reg_write;
        hlt       = t.hlt;
        debug     = t.debug;

        riscv_cg.sample();

        `uvm_info(
            get_type_name(),
            $sformatf("SUBSCRIBER_SAMPLE count=%0d PC=%08h INSTR=%08h opcode=%07b funct3=%03b funct7=%07b rd=x%0d rs1=x%0d rs2=x%0d WE=%0b HLT=%0b coverage=%0.2f%%",
                      sample_count,
                      t.pc,
                      t.instr,
                      opcode,
                      funct3,
                      funct7,
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

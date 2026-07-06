class riscv_subscriber extends uvm_subscriber #(riscv_transaction);

    `uvm_component_utils(riscv_subscriber)

    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [2:0]  instr_format;
    logic [19:0] imm_u;
    logic        reg_write;
    logic        mem_read;
    logic        mem_write;
    logic        branch_taken;
    logic        jump_taken;
    logic        hlt;
    logic [3:0]  debug;
    logic [31:0] addr;
    logic [31:0] store_data;
    logic [31:0] next_pc;
    int unsigned sample_count;

    covergroup riscv_cg;
        option.per_instance = 1;

        // Grupos principales pedidos para el tercer avance.
        cp_opcode: coverpoint opcode {
            bins r_type = {7'b0110011};
            bins i_type = {7'b0010011};
            bins lui    = {7'b0110111};
            bins auipc  = {7'b0010111};
            bins lw     = {7'b0000011};
            bins sw     = {7'b0100011};
            bins branch = {7'b1100011};
            bins jal    = {7'b1101111};
            bins jalr   = {7'b1100111};
        }

        // Formato logico usado por el subscriber:
        // 0=R, 1=I, 2=U, 3=JUMP, 4=BRANCH, 5=LOAD, 6=STORE.
        cp_instr_format: coverpoint instr_format {
            bins r_format      = {3'd0};
            bins i_format      = {3'd1};
            bins u_format      = {3'd2};
            bins jump_format   = {3'd3};
            bins branch_format = {3'd4};
            bins load_format   = {3'd5};
            bins store_format  = {3'd6};
            illegal_bins unsupported = {3'd7};
        }

        // funct3 distingue variantes R/I, branch, load y store.
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

        // funct7 diferencia ADD/SUB, SRL/SRA y SRLI/SRAI.
        cp_funct7: coverpoint funct7 {
            bins f7_0000000 = {7'b0000000};
            bins f7_0100000 = {7'b0100000};
        }

        cp_rd: coverpoint rd {
            bins rv32e_regs[] = {[5'd1:5'd15]};
        }

        cp_rs1: coverpoint rs1 {
            bins x0 = {5'd0};
            bins rv32e_regs[] = {[5'd1:5'd15]};
        }

        cp_rs2: coverpoint rs2 {
            bins x0 = {5'd0};
            bins rv32e_regs[] = {[5'd1:5'd15]};
        }

        cp_imm_u: coverpoint imm_u {
            bins zero = {20'h00000};
            bins low  = {[20'h00001:20'h000ff]};
            bins mid  = {[20'h00100:20'h00fff]};
            bins high = {[20'h01000:20'hfffff]};
        }

        cp_reg_write: coverpoint reg_write {
            bins no_write = {1'b0};
            bins write    = {1'b1};
        }

        cp_mem_read: coverpoint mem_read {
            bins no_read = {1'b0};
            bins read    = {1'b1};
        }

        cp_mem_write: coverpoint mem_write {
            bins no_write = {1'b0};
            bins write    = {1'b1};
        }

        cp_branch_taken: coverpoint branch_taken {
            bins not_taken = {1'b0};
            bins taken     = {1'b1};
        }

        cp_jump_taken: coverpoint jump_taken {
            bins not_taken = {1'b0};
            bins taken     = {1'b1};
        }

        // Tres cruces principales, manteniendo solo combinaciones semanticamente utiles.
        cross_opcode_funct3 : cross cp_opcode, cp_funct3 {
            ignore_bins no_funct3 = binsof(cp_opcode) intersect {
                7'b0110111,
                7'b0010111,
                7'b1101111
            };
        }

        cross_opcode_funct7 : cross cp_opcode, cp_funct7 {
            ignore_bins no_funct7 = binsof(cp_opcode) intersect {
                7'b0110111,
                7'b0010111,
                7'b1101111,
                7'b1100111,
                7'b0000011,
                7'b0100011,
                7'b1100011
            };
        }

        cross_opcode_reg_write : cross cp_opcode, cp_reg_write {
            ignore_bins no_writeback_expected = binsof(cp_opcode) intersect {
                7'b0100011,
                7'b1100011
            };
        }

    endgroup

    function new(string name = "riscv_subscriber", uvm_component parent = null);
        super.new(name, parent);
        riscv_cg = new();
        sample_count = 0;
    endfunction

    virtual function void write(riscv_transaction t);
        sample_count++;

        opcode       = t.instr[6:0];
        rd           = t.rd;
        rs1          = t.rs1;
        rs2          = t.rs2;
        funct3       = t.instr[14:12];
        funct7       = t.instr[31:25];
        imm_u        = t.instr[31:12];
        reg_write    = t.reg_write;
        mem_read     = t.mem_read;
        mem_write    = t.mem_write;
        branch_taken = t.branch_taken;
        jump_taken   = t.jump_taken;
        hlt          = t.hlt;
        debug        = t.debug;
        addr         = t.addr;
        store_data   = t.store_data;
        next_pc      = t.next_pc;

        case (opcode)
            7'b0110011: instr_format = 3'd0;
            7'b0010011: instr_format = 3'd1;
            7'b0110111,
            7'b0010111: instr_format = 3'd2;
            7'b1101111,
            7'b1100111: instr_format = 3'd3;
            7'b1100011: instr_format = 3'd4;
            7'b0000011: instr_format = 3'd5;
            7'b0100011: instr_format = 3'd6;
            default:    instr_format = 3'd7;
        endcase

        riscv_cg.sample();

        `uvm_info(
            get_type_name(),
            $sformatf("SUBSCRIBER_SAMPLE count=%0d PC=%08h INSTR=%08h opcode=%07b format=%0d funct3=%03b funct7=%07b imm_u=%05h rd=x%0d rs1=x%0d rs2=x%0d WE=%0b MR=%0b MW=%0b BT=%0b JT=%0b ADDR=%08h SDATA=%08h NPC=%08h HLT=%0b coverage=%0.2f%%",
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
                      mem_read,
                      mem_write,
                      branch_taken,
                      jump_taken,
                      addr,
                      store_data,
                      next_pc,
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


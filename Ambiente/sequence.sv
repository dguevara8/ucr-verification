// Modos de programa para correr pruebas separadas por tipo de instruccion.
typedef enum int {
    PROGRAM_R,
    PROGRAM_I,
    PROGRAM_U,
    PROGRAM_LOAD,
    PROGRAM_STORE,
    PROGRAM_BRANCH,
    PROGRAM_JUMP,
    PROGRAM_MIXED
} program_kind_e;

// Clase encargada de construir un programa de prueba aleatorio para darkriscv.
class riscv_sequence extends uvm_sequence #(riscv_transaction);

    `uvm_object_utils(riscv_sequence)

    localparam int INIT_SIZE = 15;
    localparam int TOTAL_PROGRAM_SIZE = 400;
    localparam int NUM_R_INSTRUCTIONS = 10;
    localparam int NUM_I_INSTRUCTIONS = 9;
    localparam int NUM_U_INSTRUCTIONS = 2;
    localparam int NUM_RANDOM_INSTRUCTIONS = NUM_R_INSTRUCTIONS + NUM_I_INSTRUCTIONS + NUM_U_INSTRUCTIONS;

    program_kind_e program_kind = PROGRAM_MIXED;

    randc logic [4:0] rd;
    randc logic [4:0] rs1;
    randc logic [4:0] rs2;
    rand logic [19:0] imm20;
    randc int unsigned instruction_id;
    int unsigned branch_case_counter;

    constraint rv32e_registers {
        rd inside {[0:15]};
        rs1 inside {[0:15]};
        rs2 inside {[0:15]};
    }

    constraint instruction_range {
        instruction_id inside {[0:NUM_RANDOM_INSTRUCTIONS-1]};
    }

    function new(string name = "riscv_sequence");
        super.new(name);
        branch_case_counter = 0;
    endfunction

    // Codifica una instruccion tipo R de RV32I/RV32E.
    function logic [31:0] make_r_type(
        logic [6:0] funct7,
        logic [2:0] funct3,
        logic [4:0] rd,
        logic [4:0] rs1,
        logic [4:0] rs2
    );
        return {funct7, rs2, rs1, funct3, rd, 7'b0110011};
    endfunction

    // Codifica una instruccion ADDI para cargar valores conocidos.
    function logic [31:0] make_addi(
        logic [4:0] rd,
        logic [4:0] rs1,
        logic [11:0] imm
    );
        return {imm, rs1, 3'b000, rd, 7'b0010011};
    endfunction

    // Codifica una instruccion tipo I aritmetico-logica.
    function logic [31:0] make_i_type(
        logic [2:0] funct3,
        logic [4:0] rd,
        logic [4:0] rs1,
        logic [11:0] imm
    );
        return {imm, rs1, funct3, rd, 7'b0010011};
    endfunction

    // Codifica una instruccion tipo I de desplazamiento: SLLI, SRLI o SRAI.
    function logic [31:0] make_shift_i_type(
        logic [6:0] funct7,
        logic [2:0] funct3,
        logic [4:0] rd,
        logic [4:0] rs1,
        logic [4:0] shamt
    );
        return {funct7, shamt, rs1, funct3, rd, 7'b0010011};
    endfunction

    // Codifica una instruccion tipo U: LUI o AUIPC.
    function logic [31:0] make_u_type(
        logic [6:0] opcode,
        logic [4:0] rd,
        logic [19:0] imm20
    );
        return {imm20, rd, opcode};
    endfunction

    // Codifica JAL. El offset esta en bytes y debe estar alineado a 2 bytes.
    function logic [31:0] make_jal(
        logic [4:0] rd,
        logic signed [20:0] offset
    );
        return {
            offset[20],
            offset[10:1],
            offset[11],
            offset[19:12],
            rd,
            7'b1101111
        };
    endfunction

    // Codifica JALR. En jump_test se usa rs1=x0 e inmediato absoluto pequeno.
    function logic [31:0] make_jalr(
        logic [4:0] rd,
        logic [4:0] rs1,
        logic signed [11:0] imm
    );
        return {imm, rs1, 3'b000, rd, 7'b1100111};
    endfunction

    // Codifica LW. El inmediato esta en bytes.
    function logic [31:0] make_load(
        logic [4:0] rd,
        logic [4:0] rs1,
        logic signed [11:0] imm
    );
        return {imm, rs1, 3'b010, rd, 7'b0000011};
    endfunction

    // Codifica SW. El inmediato esta en bytes.
    function logic [31:0] make_store(
        logic [4:0] rs2,
        logic [4:0] rs1,
        logic signed [11:0] imm
    );
        return {imm[11:5], rs2, rs1, 3'b010, imm[4:0], 7'b0100011};
    endfunction

    // Codifica instrucciones branch. El offset esta en bytes.
    function logic [31:0] make_branch(
        logic [2:0] funct3,
        logic [4:0] rs1,
        logic [4:0] rs2,
        logic signed [12:0] offset
    );
        return {
            offset[12],
            offset[10:5],
            rs2,
            rs1,
            funct3,
            offset[4:1],
            offset[11],
            7'b1100011
        };
    endfunction

    task send_instr(logic [31:0] instr, int cycle);
        riscv_transaction item;

        item = riscv_transaction::type_id::create("item");

        start_item(item);

        item.cycle     = cycle;
        item.pc        = cycle * 4;
        item.instr     = instr;
        item.rd        = instr[11:7];
        item.rs1       = instr[19:15];
        item.rs2       = instr[24:20];
        item.wdata     = 32'h00000000;
        item.addr      = 32'h00000000;
        item.store_data= 32'h00000000;
        item.next_pc   = 32'h00000000;
        item.reg_write = 1'b0;
        item.mem_read  = 1'b0;
        item.mem_write = 1'b0;
        item.branch_taken = 1'b0;
        item.jump_taken   = 1'b0;
        item.hlt       = 1'b0;
        item.debug     = 4'h0;

        finish_item(item);

        `uvm_info(
            get_type_name(),
            $sformatf("instr[%0d] PC=%08h INSTR=%08h RD=x%0d",
                      cycle, cycle * 4, instr, instr[11:7]),
            UVM_MEDIUM
        )
    endtask

    // Inicializa los registros RV32E con valores conocidos.
    task initialize_registers(ref int cycle);
        for (int i = 1; i <= INIT_SIZE; i++) begin
            send_instr(make_addi(i[4:0], 5'd0, i[11:0]), cycle);
            cycle++;
        end
    endtask

    task add_r_instruction_fixed(
        logic [6:0] funct7,
        logic [2:0] funct3,
        logic [4:0] fixed_rd,
        logic [4:0] fixed_rs1,
        logic [4:0] fixed_rs2,
        ref int cycle
    );
        send_instr(make_r_type(funct7, funct3, fixed_rd, fixed_rs1, fixed_rs2), cycle);
        cycle++;
    endtask

    task add_i_instruction_fixed(
        logic [11:0] imm,
        logic [4:0] fixed_rs1,
        logic [2:0] funct3,
        logic [4:0] fixed_rd,
        ref int cycle
    );
        send_instr(make_i_type(funct3, fixed_rd, fixed_rs1, imm), cycle);
        cycle++;
    endtask

    task add_shift_i_instruction_fixed(
        logic [6:0] funct7,
        logic [2:0] funct3,
        logic [4:0] fixed_rd,
        logic [4:0] fixed_rs1,
        logic [4:0] shamt,
        ref int cycle
    );
        send_instr(make_shift_i_type(funct7, funct3, fixed_rd, fixed_rs1, shamt), cycle);
        cycle++;
    endtask

    task add_u_instruction_fixed(
        logic [6:0] opcode,
        logic [4:0] fixed_rd,
        logic [19:0] fixed_imm20,
        ref int cycle
    );
        send_instr(make_u_type(opcode, fixed_rd, fixed_imm20), cycle);
        cycle++;
    endtask

    task add_jal_instruction_fixed(
        logic [4:0] fixed_rd,
        logic signed [20:0] offset,
        ref int cycle
    );
        send_instr(make_jal(fixed_rd, offset), cycle);
        cycle++;
    endtask

    task add_jalr_instruction_fixed(
        logic [4:0] fixed_rd,
        logic [4:0] fixed_rs1,
        logic signed [11:0] imm,
        ref int cycle
    );
        send_instr(make_jalr(fixed_rd, fixed_rs1, imm), cycle);
        cycle++;
    endtask

    task add_load_instruction_fixed(
        logic [4:0] fixed_rd,
        logic [4:0] fixed_rs1,
        logic signed [11:0] imm,
        ref int cycle
    );
        send_instr(make_load(fixed_rd, fixed_rs1, imm), cycle);
        cycle++;
    endtask

    task add_store_instruction_fixed(
        logic [4:0] fixed_rs2,
        logic [4:0] fixed_rs1,
        logic signed [11:0] imm,
        ref int cycle
    );
        send_instr(make_store(fixed_rs2, fixed_rs1, imm), cycle);
        cycle++;
    endtask

    task add_branch_instruction_fixed(
        logic [2:0] funct3,
        logic [4:0] fixed_rs1,
        logic [4:0] fixed_rs2,
        logic signed [12:0] offset,
        ref int cycle
    );
        send_instr(make_branch(funct3, fixed_rs1, fixed_rs2, offset), cycle);
        cycle++;
    endtask

    // Cluster de salto:
    //   ciclo N   : JAL o JALR salta a N+2 y escribe PC+4 en rd.
    //   ciclo N+1 : ADDI x0,x0,0 queda como filler saltado y no produce expected.
    //   ciclo N+2 : ADDI destino confirma que el flujo llego al target.
    task add_jump_cluster(ref int cycle);
        int target_cycle;
        logic signed [11:0] jalr_target_imm;

        target_cycle = cycle + 2;

        if ((cycle / 3) % 2 == 0) begin
            add_jal_instruction_fixed(5'd1, 21'sd8, cycle);
        end else begin
            jalr_target_imm = target_cycle * 4;
            add_jalr_instruction_fixed(5'd2, 5'd0, jalr_target_imm, cycle);
        end

        send_instr(make_addi(5'd0, 5'd0, 12'd0), cycle);
        cycle++;

        send_instr(make_addi(5'd3, 5'd3, 12'd1), cycle);
        cycle++;
    endtask

    // Cluster de memoria: guarda un dato conocido y luego lo carga.
    // x15 usa una base separada del programa para no pisar instrucciones.
    task add_load_cluster(ref int cycle);
        send_instr(make_addi(5'd15, 5'd0, 12'd512), cycle);
        cycle++;
        send_instr(make_addi(5'd4, 5'd0, 12'd7), cycle);
        cycle++;
        add_store_instruction_fixed(5'd4, 5'd15, 12'sd0, cycle);
        add_load_instruction_fixed(5'd5, 5'd15, 12'sd0, cycle);
    endtask

    // Cluster de store: prepara base y dato, despues ejecuta SW.
    task add_store_cluster(ref int cycle);
        send_instr(make_addi(5'd15, 5'd0, 12'd512), cycle);
        cycle++;
        send_instr(make_addi(5'd6, 5'd0, 12'd9), cycle);
        cycle++;
        add_store_instruction_fixed(5'd6, 5'd15, 12'sd0, cycle);
    endtask

    // Cluster de branch:
    // antes de cada branch se cargan operandos conocidos con ADDI.
    // El branch salta sobre un filler y cae en una instruccion observable.
    task add_branch_cluster(ref int cycle);
        int unsigned b_id;
        bit should_take;
        logic [2:0] funct3;

        b_id = (branch_case_counter / 2) % 6;
        should_take = (branch_case_counter % 2) == 0;
        branch_case_counter++;

        case (b_id)
            0: begin // BEQ
                funct3 = 3'b000;
                send_instr(make_addi(5'd8, 5'd0, 12'd5), cycle);
                cycle++;
                send_instr(make_addi(5'd9, 5'd0, should_take ? 12'd5 : 12'd6), cycle);
                cycle++;
            end
            1: begin // BNE
                funct3 = 3'b001;
                send_instr(make_addi(5'd8, 5'd0, 12'd5), cycle);
                cycle++;
                send_instr(make_addi(5'd9, 5'd0, should_take ? 12'd6 : 12'd5), cycle);
                cycle++;
            end
            2: begin // BLT
                funct3 = 3'b100;
                send_instr(make_addi(5'd8, 5'd0, should_take ? 12'd4 : 12'd9), cycle);
                cycle++;
                send_instr(make_addi(5'd9, 5'd0, should_take ? 12'd9 : 12'd4), cycle);
                cycle++;
            end
            3: begin // BGE
                funct3 = 3'b101;
                send_instr(make_addi(5'd8, 5'd0, should_take ? 12'd9 : 12'd4), cycle);
                cycle++;
                send_instr(make_addi(5'd9, 5'd0, should_take ? 12'd4 : 12'd9), cycle);
                cycle++;
            end
            4: begin // BLTU
                funct3 = 3'b110;
                send_instr(make_addi(5'd8, 5'd0, should_take ? 12'd1 : 12'd15), cycle);
                cycle++;
                send_instr(make_addi(5'd9, 5'd0, should_take ? 12'd15 : 12'd1), cycle);
                cycle++;
            end
            default: begin // BGEU
                funct3 = 3'b111;
                send_instr(make_addi(5'd8, 5'd0, should_take ? 12'd15 : 12'd1), cycle);
                cycle++;
                send_instr(make_addi(5'd9, 5'd0, should_take ? 12'd1 : 12'd15), cycle);
                cycle++;
            end
        endcase

        add_branch_instruction_fixed(funct3, 5'd8, 5'd9, 13'sd8, cycle);
        send_instr(make_addi(5'd0, 5'd0, 12'd0), cycle);
        cycle++;
        send_instr(make_addi(5'd10, 5'd10, 12'd1), cycle);
        cycle++;
    endtask

    // Agrega una instruccion R aleatoria.
    task add_random_r_instruction(ref int cycle);
        int unsigned r_id;

        if (!std::randomize(r_id, rd, rs1, rs2) with {
            r_id inside {[0:NUM_R_INSTRUCTIONS-1]};
            rd inside {[0:15]};
            rs1 inside {[0:15]};
            rs2 inside {[0:15]};
        }) begin
            `uvm_fatal(get_type_name(), "No se pudo aleatorizar una instruccion tipo R")
        end

        case (r_id)
            0: add_r_instruction_fixed(7'b0000000, 3'b000, rd, rs1, rs2, cycle); // ADD
            1: add_r_instruction_fixed(7'b0100000, 3'b000, rd, rs1, rs2, cycle); // SUB
            2: add_r_instruction_fixed(7'b0000000, 3'b001, rd, rs1, rs2, cycle); // SLL
            3: add_r_instruction_fixed(7'b0000000, 3'b010, rd, rs1, rs2, cycle); // SLT
            4: add_r_instruction_fixed(7'b0000000, 3'b011, rd, rs1, rs2, cycle); // SLTU
            5: add_r_instruction_fixed(7'b0000000, 3'b100, rd, rs1, rs2, cycle); // XOR
            6: add_r_instruction_fixed(7'b0000000, 3'b101, rd, rs1, rs2, cycle); // SRL
            7: add_r_instruction_fixed(7'b0100000, 3'b101, rd, rs1, rs2, cycle); // SRA
            8: add_r_instruction_fixed(7'b0000000, 3'b110, rd, rs1, rs2, cycle); // OR
            9: add_r_instruction_fixed(7'b0000000, 3'b111, rd, rs1, rs2, cycle); // AND
        endcase
    endtask

    // Agrega una instruccion I aleatoria.
    task add_random_i_instruction(ref int cycle);
        int unsigned i_id;
        logic [11:0] imm;
        logic [4:0] shamt;

        if (!std::randomize(i_id, rd, rs1, imm, shamt) with {
            i_id inside {[0:NUM_I_INSTRUCTIONS-1]};
            rd inside {[0:15]};
            rs1 inside {[0:15]};
            imm inside {[0:15]};
            shamt inside {[0:15]};
        }) begin
            `uvm_fatal(get_type_name(), "No se pudo aleatorizar una instruccion tipo I")
        end

        case (i_id)
            0: add_i_instruction_fixed(imm, rs1, 3'b000, rd, cycle); // ADDI
            1: add_i_instruction_fixed(imm, rs1, 3'b010, rd, cycle); // SLTI
            2: add_i_instruction_fixed(imm, rs1, 3'b011, rd, cycle); // SLTIU
            3: add_i_instruction_fixed(imm, rs1, 3'b100, rd, cycle); // XORI
            4: add_i_instruction_fixed(imm, rs1, 3'b110, rd, cycle); // ORI
            5: add_i_instruction_fixed(imm, rs1, 3'b111, rd, cycle); // ANDI
            6: add_shift_i_instruction_fixed(7'b0000000, 3'b001, rd, rs1, shamt, cycle); // SLLI
            7: add_shift_i_instruction_fixed(7'b0000000, 3'b101, rd, rs1, shamt, cycle); // SRLI
            8: add_shift_i_instruction_fixed(7'b0100000, 3'b101, rd, rs1, shamt, cycle); // SRAI
        endcase
    endtask

    // Agrega una instruccion U aleatoria.
    task add_random_u_instruction(ref int cycle);
        int unsigned u_id;

        if (!std::randomize(u_id, rd, imm20) with {
            u_id inside {[0:NUM_U_INSTRUCTIONS-1]};
            rd inside {[0:15]};
        }) begin
            `uvm_fatal(get_type_name(), "No se pudo aleatorizar una instruccion tipo U")
        end

        case (u_id)
            0: add_u_instruction_fixed(7'b0110111, rd, imm20, cycle); // LUI
            1: add_u_instruction_fixed(7'b0010111, rd, imm20, cycle); // AUIPC
        endcase
    endtask

    // Agrega una instruccion aleatoria entre las operaciones tipo R, I y U soportadas.
    task add_random_instruction(ref int cycle);
        if (!randomize()) begin
            `uvm_fatal(get_type_name(), "No se pudo aleatorizar la instruccion R/I/U")
        end

        case (instruction_id)
            0:  add_r_instruction_fixed(7'b0000000, 3'b000, rd, rs1, rs2, cycle); // ADD
            1:  add_r_instruction_fixed(7'b0100000, 3'b000, rd, rs1, rs2, cycle); // SUB
            2:  add_r_instruction_fixed(7'b0000000, 3'b001, rd, rs1, rs2, cycle); // SLL
            3:  add_r_instruction_fixed(7'b0000000, 3'b010, rd, rs1, rs2, cycle); // SLT
            4:  add_r_instruction_fixed(7'b0000000, 3'b011, rd, rs1, rs2, cycle); // SLTU
            5:  add_r_instruction_fixed(7'b0000000, 3'b100, rd, rs1, rs2, cycle); // XOR
            6:  add_r_instruction_fixed(7'b0000000, 3'b101, rd, rs1, rs2, cycle); // SRL
            7:  add_r_instruction_fixed(7'b0100000, 3'b101, rd, rs1, rs2, cycle); // SRA
            8:  add_r_instruction_fixed(7'b0000000, 3'b110, rd, rs1, rs2, cycle); // OR
            9:  add_r_instruction_fixed(7'b0000000, 3'b111, rd, rs1, rs2, cycle); // AND
            10: add_i_instruction_fixed({7'b0000000, rs2}, rs1, 3'b000, rd, cycle); // ADDI
            11: add_i_instruction_fixed({7'b0000000, rs2}, rs1, 3'b010, rd, cycle); // SLTI
            12: add_i_instruction_fixed({7'b0000000, rs2}, rs1, 3'b011, rd, cycle); // SLTIU
            13: add_i_instruction_fixed({7'b0000000, rs2}, rs1, 3'b100, rd, cycle); // XORI
            14: add_i_instruction_fixed({7'b0000000, rs2}, rs1, 3'b110, rd, cycle); // ORI
            15: add_i_instruction_fixed({7'b0000000, rs2}, rs1, 3'b111, rd, cycle); // ANDI
            16: add_shift_i_instruction_fixed(7'b0000000, 3'b001, rd, rs1, rs2, cycle); // SLLI
            17: add_shift_i_instruction_fixed(7'b0000000, 3'b101, rd, rs1, rs2, cycle); // SRLI
            18: add_shift_i_instruction_fixed(7'b0100000, 3'b101, rd, rs1, rs2, cycle); // SRAI
            19: add_u_instruction_fixed(7'b0110111, rd, imm20, cycle); // LUI
            20: add_u_instruction_fixed(7'b0010111, rd, imm20, cycle); // AUIPC
            default: begin
                `uvm_fatal(
                    get_type_name(),
                    $sformatf("instruction_id fuera de rango: %0d", instruction_id)
                )
            end
        endcase
    endtask

    task add_instruction_for_mode(ref int cycle);
        case (program_kind)
            PROGRAM_R:     add_random_r_instruction(cycle);
            PROGRAM_I:     add_random_i_instruction(cycle);
            PROGRAM_U:     add_random_u_instruction(cycle);
            PROGRAM_LOAD:  add_load_cluster(cycle);
            PROGRAM_STORE: add_store_cluster(cycle);
            PROGRAM_BRANCH:add_branch_cluster(cycle);
            PROGRAM_JUMP:  add_jump_cluster(cycle);
            PROGRAM_MIXED: add_random_instruction(cycle);
            default:       add_random_instruction(cycle);
        endcase
    endtask

    function string program_kind_name();
        case (program_kind)
            PROGRAM_R:     return "R";
            PROGRAM_I:     return "I";
            PROGRAM_U:     return "U";
            PROGRAM_LOAD:  return "LOAD";
            PROGRAM_STORE: return "STORE";
            PROGRAM_BRANCH:return "BRANCH";
            PROGRAM_JUMP:  return "JUMP";
            PROGRAM_MIXED: return "MIXED";
            default:       return "UNKNOWN";
        endcase
    endfunction

    // Construye un programa controlado:
    // 15 ADDI de inicializacion y luego instrucciones del modo seleccionado.
    // Se rellena con NOP para evitar que el JAL final genere "invalid IDATA".
    task body();
        int cycle;

        cycle = 0;

        `uvm_info(
            get_type_name(),
            $sformatf("Generando programa kind=%s init=%0d total=%0d",
                      program_kind_name(),
                      INIT_SIZE,
                      TOTAL_PROGRAM_SIZE),
            UVM_MEDIUM
        )

        initialize_registers(cycle);

        while (cycle < TOTAL_PROGRAM_SIZE) begin
            if ((program_kind == PROGRAM_JUMP) && (cycle > TOTAL_PROGRAM_SIZE - 3)) begin
                send_instr(make_addi(5'd0, 5'd0, 12'd0), cycle);
                cycle++;
            end else if ((program_kind == PROGRAM_LOAD) && (cycle > TOTAL_PROGRAM_SIZE - 4)) begin
                send_instr(make_addi(5'd0, 5'd0, 12'd0), cycle);
                cycle++;
            end else if ((program_kind == PROGRAM_STORE) && (cycle > TOTAL_PROGRAM_SIZE - 3)) begin
                send_instr(make_addi(5'd0, 5'd0, 12'd0), cycle);
                cycle++;
            end else if ((program_kind == PROGRAM_BRANCH) && (cycle > TOTAL_PROGRAM_SIZE - 5)) begin
                send_instr(make_addi(5'd0, 5'd0, 12'd0), cycle);
                cycle++;
            end else begin
                add_instruction_for_mode(cycle);
            end
        end

        `uvm_info(
            get_type_name(),
            $sformatf("Programa generado con %0d instrucciones", cycle),
            UVM_LOW
        )
    endtask

endclass

// Clase encargada de construir un programa de prueba aleatorio para darkriscv.
class riscv_sequence extends uvm_sequence #(riscv_transaction);

  `uvm_object_utils(riscv_sequence)

    localparam int PROGRAM_SIZE = 80;
    localparam int NUM_R_INSTRUCTIONS = 10;
    localparam int NUM_I_INSTRUCTIONS = 9;
    localparam int NUM_U_RANDOM_INSTRUCTIONS = 2;
    localparam int NUM_U_DIRECTED_INSTRUCTIONS = 8;
    localparam int NUM_RANDOM_INSTRUCTIONS = NUM_R_INSTRUCTIONS + NUM_I_INSTRUCTIONS + NUM_U_RANDOM_INSTRUCTIONS;

    randc logic [4:0] rd;
    randc logic [4:0] rs1;
    randc logic [4:0] rs2;
    rand logic [19:0] imm20;
    randc int unsigned instruction_id;

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
        item.reg_write = 1'b0;
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

    // Agrega una instruccion R con registros aleatorios validos para RV32E.
    task add_r_instruction(logic [6:0] funct7, logic [2:0] funct3, ref int cycle);
        logic [31:0] instr;

        if (!std::randomize(rd, rs1, rs2) with {
            rd inside {[0:15]};
            rs1 inside {[0:15]};
            rs2 inside {[0:15]};
        }) begin
            `uvm_fatal(get_type_name(), "No se pudieron aleatorizar los registros")
        end

        instr = make_r_type(funct7, funct3, rd, rs1, rs2);
        send_instr(instr, cycle);
        cycle++;
    endtask

     // Agrega una instruccion tipo I con inmediato positivo pequeno.
    // Se usa rs2 como fuente aleatoria para formar el inmediato.
    task add_i_instruction(logic [2:0] funct3, ref int cycle);
        logic [31:0] instr;

        if (!std::randomize(rd, rs1, rs2) with {
            rd inside {[0:15]};
            rs1 inside {[0:15]};
            rs2 inside {[0:15]};
        }) begin
            `uvm_fatal(get_type_name(), "No se pudieron aleatorizar los registros")
        end

        instr = make_i_type(funct3, rd, rs1, {7'b0000000, rs2});
        send_instr(instr, cycle);
        cycle++;
    endtask

    // Agrega una instruccion tipo I de desplazamiento con shamt valido.
    // rs2 se reutiliza como shamt porque esta limitado al rango 0..15.
    task add_shift_i_instruction(logic [6:0] funct7, logic [2:0] funct3, ref int cycle);
        logic [31:0] instr;

        if (!std::randomize(rd, rs1, rs2) with {
            rd inside {[0:15]};
            rs1 inside {[0:15]};
            rs2 inside {[0:15]};
        }) begin
            `uvm_fatal(get_type_name(), "No se pudieron aleatorizar los registros")
        end

        instr = make_shift_i_type(funct7, funct3, rd, rs1, rs2);
        send_instr(instr, cycle);
        cycle++;
    endtask

    // Agrega una instruccion tipo U con inmediato aleatorio.
    task add_u_instruction(logic [6:0] opcode, ref int cycle);
        logic [31:0] instr;

        if (!std::randomize(rd, imm20) with {
            rd inside {[0:15]};
        }) begin
            `uvm_fatal(get_type_name(), "No se pudo aleatorizar la instruccion tipo U")
        end

        instr = make_u_type(opcode, rd, imm20);
        send_instr(instr, cycle);
        cycle++;
    endtask

    // Agrega una instruccion tipo U con inmediato conocido para cobertura dirigida.
    task add_u_instruction_fixed(
        logic [6:0] opcode,
        logic [4:0] fixed_rd,
        logic [19:0] fixed_imm20,
        ref int cycle
    );
        send_instr(make_u_type(opcode, fixed_rd, fixed_imm20), cycle);
        cycle++;
    endtask

    // Agrega una instruccion aleatoria entre las operaciones tipo R, I y U soportadas.
    task add_random_instruction(ref int cycle);
        logic [31:0] instr;

        if (!randomize()) begin
            `uvm_fatal(get_type_name(), "No se pudo aleatorizar la instruccion R/I/U")
        end

        case (instruction_id)
          0: instr = make_r_type(7'b0000000, 3'b000, rd, rs1, rs2); // add
          1: instr = make_r_type(7'b0100000, 3'b000, rd, rs1, rs2); // sub
          2: instr = make_r_type(7'b0000000, 3'b001, rd, rs1, rs2); // sll
          3: instr = make_r_type(7'b0000000, 3'b010, rd, rs1, rs2); // slt
          4: instr = make_r_type(7'b0000000, 3'b011, rd, rs1, rs2); // sltu
          5: instr = make_r_type(7'b0000000, 3'b100, rd, rs1, rs2); // xor
          6: instr = make_r_type(7'b0000000, 3'b101, rd, rs1, rs2); // srl
          7: instr = make_r_type(7'b0100000, 3'b101, rd, rs1, rs2); // sra
          8: instr = make_r_type(7'b0000000, 3'b110, rd, rs1, rs2); // or
          9: instr = make_r_type(7'b0000000, 3'b111, rd, rs1, rs2); // and
          10: instr = make_i_type(3'b000, rd, rs1, {7'b0000000, rs2}); // addi
          11: instr = make_i_type(3'b010, rd, rs1, {7'b0000000, rs2}); // slti
          12: instr = make_i_type(3'b011, rd, rs1, {7'b0000000, rs2}); // sltiu
          13: instr = make_i_type(3'b100, rd, rs1, {7'b0000000, rs2}); // xori
          14: instr = make_i_type(3'b110, rd, rs1, {7'b0000000, rs2}); // ori
          15: instr = make_i_type(3'b111, rd, rs1, {7'b0000000, rs2}); // andi
          16: instr = make_shift_i_type(7'b0000000, 3'b001, rd, rs1, rs2); // slli
          17: instr = make_shift_i_type(7'b0000000, 3'b101, rd, rs1, rs2); // srli
          18: instr = make_shift_i_type(7'b0100000, 3'b101, rd, rs1, rs2); // srai
          19: instr = make_u_type(7'b0110111, rd, imm20); // lui
          20: instr = make_u_type(7'b0010111, rd, imm20); // auipc
          default: begin
              `uvm_fatal(
                  get_type_name(),
                  $sformatf("instruction_id fuera de rango: %0d", instruction_id)
              )
          end
        endcase

        send_instr(instr, cycle);
        cycle++;
    endtask

  	// Inicializa los registros RV32E con valores conocidos.
    task initialize_registers(ref int cycle);
        for (int i = 1; i <= 15; i++) begin
            send_instr(make_addi(i[4:0], 5'd0, i[11:0]), cycle);
            cycle++;
        end
    endtask

    // Construye un programa con instrucciones tipo R, tipo I y tipo U soportadas.
    task body();
        int cycle;

        cycle = 0;

        `uvm_info(
            get_type_name(),
            $sformatf("Generando programa aleatorio tipo R/tipo I/tipo U: init=15 programa=%0d total=%0d",
                      PROGRAM_SIZE,
                      PROGRAM_SIZE + 15),
            UVM_MEDIUM
        )

        initialize_registers(cycle);

      add_r_instruction(7'b0000000, 3'b000, cycle); // add
      add_r_instruction(7'b0100000, 3'b000, cycle); // sub
      add_r_instruction(7'b0000000, 3'b001, cycle); // sll
      add_r_instruction(7'b0000000, 3'b010, cycle); // slt
      add_r_instruction(7'b0000000, 3'b011, cycle); // sltu
      add_r_instruction(7'b0000000, 3'b100, cycle); // xor
      add_r_instruction(7'b0000000, 3'b101, cycle); // srl
      add_r_instruction(7'b0100000, 3'b101, cycle); // sra
      add_r_instruction(7'b0000000, 3'b110, cycle); // or
      add_r_instruction(7'b0000000, 3'b111, cycle); // and

      add_i_instruction(3'b000, cycle); // addi
      add_i_instruction(3'b010, cycle); // slti
      add_i_instruction(3'b011, cycle); // sltiu
      add_i_instruction(3'b100, cycle); // xori
      add_i_instruction(3'b110, cycle); // ori
      add_i_instruction(3'b111, cycle); // andi

      add_shift_i_instruction(7'b0000000, 3'b001, cycle); // slli
      add_shift_i_instruction(7'b0000000, 3'b101, cycle); // srli
      add_shift_i_instruction(7'b0100000, 3'b101, cycle); // srai

      add_u_instruction_fixed(7'b0110111, 5'd1, 20'h00000, cycle); // lui, imm zero
      add_u_instruction_fixed(7'b0110111, 5'd2, 20'h00010, cycle); // lui, imm low
      add_u_instruction_fixed(7'b0110111, 5'd3, 20'h00100, cycle); // lui, imm mid
      add_u_instruction_fixed(7'b0110111, 5'd4, 20'h01000, cycle); // lui, imm high
      add_u_instruction_fixed(7'b0010111, 5'd5, 20'h00000, cycle); // auipc, imm zero
      add_u_instruction_fixed(7'b0010111, 5'd6, 20'h00010, cycle); // auipc, imm low
      add_u_instruction_fixed(7'b0010111, 5'd7, 20'h00100, cycle); // auipc, imm mid
      add_u_instruction_fixed(7'b0010111, 5'd8, 20'h01000, cycle); // auipc, imm high

        repeat (PROGRAM_SIZE - NUM_R_INSTRUCTIONS - NUM_I_INSTRUCTIONS - NUM_U_DIRECTED_INSTRUCTIONS - 1) begin
            add_random_instruction(cycle);
        end

        send_instr(32'h0000006F, cycle); // jal x0, 0

        `uvm_info(get_type_name(),
                  $sformatf("Programa generado con %0d instrucciones", cycle + 1),
                  UVM_LOW)
    endtask

endclass

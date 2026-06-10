// Clase encargada de construir un programa de prueba aleatorio para darkriscv.
class riscv_sequence extends uvm_sequence #(riscv_transaction);

  `uvm_object_utils(riscv_sequence)

    localparam int PROGRAM_SIZE = 40;
    localparam int NUM_R_INSTRUCTIONS = 10;
    localparam int NUM_I_INSTRUCTIONS = 9;
    localparam int NUM_U_INSTRUCTIONS = 2;

    randc logic [4:0] rd;
    randc logic [4:0] rs1;
    randc logic [4:0] rs2;
    randc int unsigned instruction_id;

    constraint rv32e_registers {
        rd inside {[0:15]};
        rs1 inside {[0:15]};
        rs2 inside {[0:15]};
    }

    constraint r_instruction_range {
        instruction_id inside {[0:NUM_R_INSTRUCTIONS-1]};
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
    	logic [19:0] imm20,
    	logic [4:0] rd,
    	logic [6:0] opcode
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

    // Agrega una instruccion tipo U.
    task add_u_instruction(logic [6:0] opcode, ref int cycle);
    	logic [31:0] instr;
    	logic [19:0] imm20;

    	if (!std::randomize(rd, imm20) with {
        	rd inside {[0:15]};
        	imm20 inside {[20'h00001:20'h000ff]};
    	}) begin
        	`uvm_fatal(get_type_name(), "No se pudo aleatorizar la instruccion 	tipo U")
    	end

    	instr = make_u_type(imm20, rd, opcode);
    	send_instr(instr, cycle);
    	cycle++;
	endtask

    // Agrega una instruccion R aleatoria entre las operaciones soportadas.
    task add_random_r_instruction(ref int cycle);
        logic [31:0] instr;

        if (!randomize()) begin
            `uvm_fatal(get_type_name(), "No se pudo aleatorizar la instruccion R")
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

    // Construye un programa con instrucciones tipo R y tipo I soportadas.
    task body();
        int cycle;

        cycle = 0;

        `uvm_info(get_type_name(), "Generando programa aleatorio tipo R/tipo I", UVM_MEDIUM)

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

      add_u_instruction(7'b0110111, cycle); // lui
      add_u_instruction(7'b0010111, cycle); // auipc

        repeat (PROGRAM_SIZE - NUM_R_INSTRUCTIONS - NUM_I_INSTRUCTIONS - NUM_I_INSTRUCTIONS - 1) begin
            add_random_r_instruction(cycle);
        end

        send_instr(32'h0000006F, cycle); // jal x0, 0

        `uvm_info(get_type_name(),
                  $sformatf("Programa generado con %0d instrucciones", cycle + 1),
                  UVM_LOW)
    endtask

endclass

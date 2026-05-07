// Clase encargada de construir un programa de prueba aleatorio para darkriscv.
class stimulus;
    localparam int PROGRAM_SIZE = 20;
    localparam int NUM_R_INSTRUCTIONS = 10;

    randc logic [4:0] rd;
    randc logic [4:0] rs1;
    randc logic [4:0] rs2;
    randc int unsigned instruction_id;

    logic [31:0] instructions[$];

    constraint rv32e_registers {
        rd inside {[1:15]};
        rs1 inside {[0:15]};
        rs2 inside {[0:15]};
    }

    constraint r_instruction_range {
        instruction_id inside {[0:NUM_R_INSTRUCTIONS-1]};
    }

    // Codifica una instruccion tipo R de RV32I/RV32E.
    function logic [31:0] make_r_type(logic [6:0] funct7,
                                      logic [2:0] funct3,
                                      logic [4:0] rd,
                                      logic [4:0] rs1,
                                      logic [4:0] rs2);
        return {funct7, rs2, rs1, funct3, rd, 7'b0110011};
    endfunction

    // Agrega la instruccion R usando los registros aleatorizados.
    task push_r_instruction(logic [6:0] funct7, logic [2:0] funct3);
        instructions.push_back(make_r_type(funct7, funct3, rd, rs1, rs2));
    endtask

    // Agrega una instruccion R con registros aleatorios validos para RV32E.
    task add_r_instruction(logic [6:0] funct7, logic [2:0] funct3);
        if (!std::randomize(rd, rs1, rs2) with {
            rd inside {[1:15]};
            rs1 inside {[0:15]};
            rs2 inside {[0:15]};
        }) begin
            $fatal(1, "[STIMULUS] No se pudieron aleatorizar los registros");
        end
        push_r_instruction(funct7, funct3);
    endtask

    // Agrega una instruccion R aleatoria entre las operaciones soportadas.
    task add_random_r_instruction();
        if (!randomize()) begin
            $fatal(1, "[STIMULUS] No se pudo aleatorizar la instruccion R");
        end

        case (instruction_id)
            0: push_r_instruction(7'b0000000, 3'b000); // add
            1: push_r_instruction(7'b0100000, 3'b000); // sub
            2: push_r_instruction(7'b0000000, 3'b001); // sll
            3: push_r_instruction(7'b0000000, 3'b010); // slt
            4: push_r_instruction(7'b0000000, 3'b011); // sltu
            5: push_r_instruction(7'b0000000, 3'b100); // xor
            6: push_r_instruction(7'b0000000, 3'b101); // srl
            7: push_r_instruction(7'b0100000, 3'b101); // sra
            8: push_r_instruction(7'b0000000, 3'b110); // or
            9: push_r_instruction(7'b0000000, 3'b111); // and
        endcase
    endtask

    // Construye un programa con todas las instrucciones tipo R soportadas.
    task build_program();
        instructions.delete();

        add_r_instruction(7'b0000000, 3'b000); // add
        add_r_instruction(7'b0100000, 3'b000); // sub
        add_r_instruction(7'b0000000, 3'b001); // sll
        add_r_instruction(7'b0000000, 3'b010); // slt
        add_r_instruction(7'b0000000, 3'b011); // sltu
        add_r_instruction(7'b0000000, 3'b100); // xor
        add_r_instruction(7'b0000000, 3'b101); // srl
        add_r_instruction(7'b0100000, 3'b101); // sra
        add_r_instruction(7'b0000000, 3'b110); // or
        add_r_instruction(7'b0000000, 3'b111); // and

        repeat (PROGRAM_SIZE - NUM_R_INSTRUCTIONS) begin
            add_random_r_instruction();
        end
    endtask

    // Imprime el programa generado para facilitar la depuracion.
    task print_program();
        $display("[STIMULUS] Programa aleatorio tipo R generado:");
        foreach (instructions[i]) begin
            $display("[STIMULUS] instr[%0d] = %08h", i, instructions[i]);
        end
    endtask
endclass

class riscv_monitor extends uvm_monitor;

    `uvm_component_utils(riscv_monitor)

    virtual ifc_darksocv ifc_darksocv_obj;

    uvm_analysis_port #(riscv_transaction) mon2scb_port;
    uvm_analysis_port #(riscv_transaction) mon2sub_port;

    int cycle_count;

    function new(string name = "riscv_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        mon2scb_port = new("mon2scb_port", this);
        mon2sub_port = new("mon2sub_port", this);

        if (!uvm_config_db #(virtual ifc_darksocv)::get(this, "", "ifc_darksocv_obj", ifc_darksocv_obj)) begin
            `uvm_fatal(get_type_name(), "No se encontro la interfaz virtual ifc_darksocv_obj")
        end

        cycle_count = 0;
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

            7'b0110111: return "LUI";
            7'b0010111: return "AUIPC";
            7'b1101111: return "JAL";
            7'b1100111: return (funct3 == 3'b000) ? "JALR" : "UNKNOWN";

            default: return "UNKNOWN";
        endcase
    endfunction

    virtual task run_phase(uvm_phase phase);
        riscv_transaction tr;

        forever begin
            @(posedge ifc_darksocv_obj.clk);
            cycle_count++;

            if (!ifc_darksocv_obj.reset &&
                !ifc_darksocv_obj.core_reset &&
                (ifc_darksocv_obj.reg_write ||
                 ifc_darksocv_obj.mem_read ||
                 ifc_darksocv_obj.mem_write ||
                 ifc_darksocv_obj.is_branch ||
                 ifc_darksocv_obj.is_jump)) begin

                tr = riscv_transaction::type_id::create("tr");

                tr.cycle        = cycle_count;
                tr.pc           = ifc_darksocv_obj.pc;
                tr.instr        = ifc_darksocv_obj.instr;
                tr.rd           = ifc_darksocv_obj.rd;
                tr.rs1          = ifc_darksocv_obj.instr[19:15];
                tr.rs2          = ifc_darksocv_obj.instr[24:20];
                tr.wdata        = ifc_darksocv_obj.wdata;
                tr.addr         = ifc_darksocv_obj.addr;
                tr.store_data   = ifc_darksocv_obj.store_data;
                tr.next_pc      = ifc_darksocv_obj.next_pc;
                tr.reg_write    = ifc_darksocv_obj.reg_write;
                tr.mem_read     = ifc_darksocv_obj.mem_read;
                tr.mem_write    = ifc_darksocv_obj.mem_write;
                tr.branch_taken = ifc_darksocv_obj.branch_taken;
                tr.jump_taken   = ifc_darksocv_obj.jump_taken;
                tr.hlt          = ifc_darksocv_obj.hlt;
                tr.debug        = ifc_darksocv_obj.debug;

                `uvm_info(
                    get_type_name(),
                    $sformatf("OBSERVADO ciclo=%0d PC=%08h INSTR=%08h OP=%s RD=x%0d WDATA=%0d ADDR=%08h SDATA=%08h NPC=%08h WE=%0b MR=%0b MW=%0b BT=%0b JT=%0b",
                              tr.cycle,
                              tr.pc,
                              tr.instr,
                              get_op_name(tr.instr),
                              tr.rd,
                              $signed(tr.wdata),
                              tr.addr,
                              tr.store_data,
                              tr.next_pc,
                              tr.reg_write,
                              tr.mem_read,
                              tr.mem_write,
                              tr.branch_taken,
                              tr.jump_taken),
                    UVM_MEDIUM
                )

                // Por ahora el scoreboard compara writeback. Store/branch se mandan
                // al subscriber para cobertura y luego se pueden elevar a checker.
                if (tr.reg_write) begin
                    mon2scb_port.write(tr);
                end

                mon2sub_port.write(tr);
            end
        end
    endtask

endclass

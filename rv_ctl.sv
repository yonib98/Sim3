// **********************************************************************
// Technion EE 044252: Digital Systems and Computer Structure course    *
// Simple Multicycle RISC-V model                                       *
// ==============================                                       *
// Control plane                                                        *
// **********************************************************************
 module rv_ctl
 (

     // Output to memory
     output logic memrw,

     // Interface with datapath
     input logic [31:0] instr,
     input logic zero,
     output logic pcsourse,
     output logic pcwrite,
     output logic pccen,
     output logic irwrite,
     output logic addrwrite,
     output logic [1:0] wbsel,
     output logic regwen,
     output logic [1:0] immsel,
     output logic asel,
     output logic bsel,
     output logic [3:0] alusel,
     output logic sw_sel,
     output logic mdrwrite,
     
     // Clock and reset
     input logic clk,
     input logic rst
 );
 
 // Design parameters
 `include "params.inc"

 // =========================================================
 // The state machine
 // =================

 // State declarations
 typedef enum{
    FETCH       = 0,
    DECODE      = 1,
    LSW_ADDR    = 2,
    LW_MEM      = 3,
    LW_WB       = 4,
    SW_MEM      = 5,
    RTYPE_ALU   = 6,
    RTYPE_WB    = 7,
    BEQ_EXEC    = 8,
    JAL_EXEC    = 9,
    LW_HOLD     = 10,
    SW2_SUB     = 11,
    SW_CONT     = 12
	} sm_type;

sm_type current,next;

 logic [9:0] opcode_funct3;

 // Next state sampling
 always_ff @(posedge clk or posedge rst)
     if (rst)            current <= FETCH;
     else                current <= next;

 // Opcode + Funct3 fields define the instruction
 assign opcode_funct3 = {instr[6:0], instr[14:12]};

 // State transitions
 // ~~~~~~~~~~~~~~~~~
 always_comb
 begin
    case (current)
        FETCH:
            next = DECODE;
        DECODE: begin
            casex (opcode_funct3)
                LW:     next = LSW_ADDR;
                SW:     next = LSW_ADDR;
                ALU:    next = RTYPE_ALU;
                BEQ:    next = BEQ_EXEC;
                JAL:    next = JAL_EXEC;
                // For unimplemented instructions do nothing
                default:next = FETCH; 
            endcase
        end
        LSW_ADDR: begin
            casex (opcode_funct3)
                LW:     next = LW_HOLD;
                SW:     next = SW_MEM;
                // This is never reached
                default:next = SW_MEM;
            endcase
        end
        SW_MEM: begin
            casex (opcode_funct3)
                SW2: next=SW2_SUB;
                SW: next=SW_CONT;
                default:next = SW_CONT;
            endcase
        end

        SW2_SUB: 
            next = FETCH;
        SW_CONT:
            next = FETCH; 
        LW_HOLD:
            next = LW_MEM;
        LW_MEM:
            next = LW_WB;
        LW_WB:
            next = FETCH;
        RTYPE_ALU:
            next = RTYPE_WB;
        RTYPE_WB:
            next = FETCH;
        BEQ_EXEC:
            next = FETCH;
        JAL_EXEC:
            next = FETCH;
        default: // Should never reach this
            next = FETCH;
    endcase
 end

 // State Machine Outputs
 // ~~~~~~~~~~~~~~~~~~~~~
 
 always_comb
 begin
     // Default values of all the controls to avoid latches
    pcsourse = PC_INC;
    pcwrite = 1'b0;
    pccen = 1'b0;
    irwrite = 1'b0;
    addrwrite=1'b0;
    wbsel = WB_PC;
    regwen = 1'b0;
    immsel = IMM_B;
    asel = ALUA_REG;
    bsel = ALUB_REG;
    alusel = ALU_ADD;
    mdrwrite = 1'b0;
    memrw = 1'b0;
    sw_sel=B;
    case (current)
        FETCH:
        begin
            pccen       = 1'b1;
            pcwrite     = 1'b1;
            irwrite     = 1'b1;
            pcsourse    = PC_INC;
        end
        DECODE: begin
            immsel      = IMM_B;
            asel        = ALUA_PCC;
            bsel        = ALUB_IMM;
            alusel      = ALU_ADD;
        end
        LSW_ADDR: begin
            immsel      = (opcode_funct3 == LW) ? IMM_L : IMM_S;
            asel        = ALUA_REG;
            bsel        = ALUB_IMM;
            alusel      = ALU_ADD;
        end
        LW_HOLD: begin
            immsel      = (opcode_funct3 == LW) ? IMM_L : IMM_S;
            asel        = ALUA_REG;
            bsel        = ALUB_IMM;
            alusel      = ALU_ADD;
            addrwrite   = 1'b1;
        end
        LW_MEM:
            mdrwrite    = 1'b1;
        LW_WB: begin
            wbsel       = WB_MDR;
            regwen      = 1'b1;
        end
        SW_MEM: begin
            addrwrite   = 1'b1;
            alusel      = (opcode_funct3==SW2) ? ALU_SUB : ALU_ADD;
            asel        = (opcode_funct3==SW2) ? ALUA_0  : ALUA_REG;
        end
        SW_CONT: begin
            memrw       = 1'b1;
        end
        SW2_SUB: begin
            SW_SEL      = ALU_OUT;
            memrw       = 1'b1;
        RTYPE_ALU: begin
            asel        = ALUA_REG;
            bsel        = ALUB_REG;
            alusel      = {instr[14:12],instr[30]}; // Funct3 and INST[30]
        end
        RTYPE_WB: begin
            wbsel       = WB_ALUOUT;
            regwen      = 1'b1;
        end
        BEQ_EXEC: begin
            asel        = ALUA_REG;
            bsel        = ALUB_REG;
            alusel      = ALU_SUB;
            pcsourse    = PC_ALU;
            if (zero)
                pcwrite = 1'b1;
        end
        JAL_EXEC: begin
            immsel      = IMM_J;
            asel        = ALUA_PCC;
            bsel        = ALUB_IMM;
            alusel      = ALU_ADD;
            pcsourse    = PC_ALU;
            pcwrite     = 1'b1;
            regwen      = 1'b1;
            wbsel       = WB_PC;
        end
    endcase
 end

endmodule

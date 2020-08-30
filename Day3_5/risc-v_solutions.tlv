\m4_TLV_version 1d: tl-x.org
\SV
   // /====================\
   // | DAY4 LAB WORK - RISCV CPU SINGLE STAGE IMPLEMENTATION |
   // \====================/
   // This code can be found in: https://github.com/stevehoover/RISC-V_MYTH_Workshop
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/RISC-V_MYTH_Workshop/c1719d5b338896577b79ee76c2f443ca2a76e14f/tlv_lib/risc-v_shell_lib.tlv'])

\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV

   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program for MYTH Workshop to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  r10 (a0): In: 0, Out: final sum
   //  r12 (a2): 10
   //  r13 (a3): 1..10
   //  r14 (a4): Sum
   // 
   // External to function:
   m4_asm(ADD, r10, r0, r0)             // Initialize r10 (a0) to 0.
   // Function:
   m4_asm(ADD, r14, r10, r0)            // Initialize sum register a4 with 0x0
   m4_asm(ADDI, r12, r10, 1010)         // Store count of 10 in register a2.
   m4_asm(ADD, r13, r10, r0)            // Initialize intermediate sum register a3 with 0
   // Loop:
   m4_asm(ADD, r14, r13, r14)           // Incremental addition
   m4_asm(ADDI, r13, r13, 1)            // Increment intermediate register by 1
   m4_asm(BLT, r13, r12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
   m4_asm(ADD, r10, r14, r0)            // Store final result to register a0 so that it can be read by main program
   
   // Optional:
   // m4_asm(JAL, r7, 00000000000000000000) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)

   |cpu
      @0
         $reset = *reset;
         
         //PC IMPLEMENTATION 
         $pc[31:0] = 
            >>1$reset ? 
            32'b0 :
            >>1$pc + 32'd4;
      @1   
         // Instruction Memory Logic
         $imem_rd_en = !$reset;
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+1:2];
         $instr[31:0] = $imem_rd_data[31:0];
         
         //Decode Logic - Instruction Decode
         // I - Type Instructions
         $is_i_instr = $instr[6:2] ==? 5'b0000x || 
                       $instr[6:2] ==? 5'b001x0 || 
                       $instr[6:2] ==? 5'b11001;
         // R - Type Instructions
         $is_r_instr = $instr[6:2] ==? 5'b011x0 || 
                       $instr[6:2] ==? 5'b01011 || 
                       $instr[6:2] ==? 5'b10100;
         // S - Type Instructions
         $is_s_instr = $instr[6:2] ==? 5'b0100x;
         // J - Type Instructions
         $is_j_instr = $instr[6:2] ==? 5'b11011;
         // U - Type Instructions
         $is_u_instr = $instr[6:2] ==? 5'b0x101;
         // B - Type Instructions
         $is_b_instr = $instr[6:2] ==? 5'b11000;
         
         //Immediate Type
         $imm[31:0] = $is_i_instr ? { {21{$instr[31]}}, $instr[30:20]} :
                      $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7]} :
                      $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0} :
                      $is_u_instr ? {$instr[31:12], 12'b0} :
                      $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0} :
                      32'b0;
         
         //Other Instruction Fields
         $rs2_valid    = $is_r_instr || $is_s_instr || $is_b_instr;
         $rs1_valid    = $is_r_instr || $is_s_instr || $is_b_instr || $is_i_instr;
         $rd_valid     = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
         $funct3_valid = $is_r_instr || $is_s_instr || $is_b_instr || $is_i_instr;
         $funct7_valid = $is_r_instr;
         
         $opcode[6:0] = $instr[6:0];
         ?$rs2_valid
            $rs2[4:0]    = $instr[24:20];
         ?$rs1_valid
            $rs1[3:0]    = $instr[19:15];
         ?$rd_valid
            $rd[4:0]     = $instr[11:7];
         ?$funct3_valid
            $funct3[2:0] = $instr[14:12];
         ?$funct7_valid
            $funct7[6:0] = $instr[31:25];
         
         //Decoding Instructions 
         $dec_bits[10:0] = {$funct7[5] ,$funct3, $opcode};
         //Branch Instructions 
         //BEQ - Branch on equal 
         $is_beq = $dec_bits ==? 11'bx_000_1100011;
         //BNE - Branch on not equal
         $is_bne = $dec_bits ==? 11'bx_001_1100011;
         //BLT - Branch on less than
         $is_blt = $dec_bits ==? 11'bx_100_1100011;
         //BGE - Branch on greater than
         $is_bge = $dec_bits ==? 11'bx_101_1100011;
         //BLTU - Branch on less than equal
         $is_bltu = $dec_bits ==? 11'bx_110_1100011;
         //BGEU - Branch on greater than equal
         $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
         
         //ADD Instructions 
         $is_addi = $dec_bits ==? 11'bx_000_0010011;
         $is_add  = $dec_bits ==? 11'b0_000_0110011;
         
         //Register File Reads
         //RS1 Reads
         $rf_rd_en1 = $rs1_valid;
         $rf_rd_index1[4:0] = $rs1;
         //RS2 Reads
         $rf_rd_en2 = $rs2_valid;
         $rf_rd_index2[4:0] = $rs2;
         
         //Output of Register File Read to ALU as Input 
         $src1[31:0] = $rf_rd_data1;
         $src2[31:0] = $rf_rd_data2;
         
         //ALU Implmentation - ADD , ADDI
         $result[31:0] = $is_addi ? 
                         $src1[31:0] + $imm[31:0] :
                         $is_add ?
                         $src1[31:0] + $src2[31:0] :
                         32'bx;
         
         
         //CLEARING WARNINGS
         `BOGUS_USE($is_addi $is_add $is_beq $is_bne $is_blt $is_bge $is_bltu $is_bgeu $imm $imem_rd_en $imem_rd_addr $rd $rs1 $rs2 )
      // Note: Because of the magic we are using for visualisation, if visualisation is enabled below,
      //       be sure to avoid having unassigned signals (which you might be using for random inputs)
      //       other than those specifically expected in the labs. You'll get strange errors for these.

   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
   
   // Macro instantiations for:
   //  o instruction memory
   //  o register file
   //  o data memory
   //  o CPU visualization
   |cpu
      m4+imem(@1)    // Args: (read stage)
      m4+rf(@1, @1)  // Args: (read stage, write stage) - if equal, no register bypass is required
      //m4+dmem(@4)    // Args: (read/write stage)
   
   m4+cpu_viz(@4)    // For visualisation, argument should be at least equal to the last stage of CPU logic
                       // @4 would work for all labs
\SV
   endmodule

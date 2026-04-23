module processor_core (
  input  logic        clk_i, 
  input  logic        rst_i,

  input  logic        stall_i,     

  input  logic [31:0] instr_i,   
  output logic [31:0] instr_addr_o,   

  input  logic [31:0] mem_rd_i,     
  output logic [31:0] mem_addr_o,    
  output logic [ 2:0] mem_size_o,   
  output logic        mem_req_o,     
  output logic        mem_we_o,       // 1 - запись, 0 - чтение
  output logic [31:0] mem_wd_o,       // Данные для записи в память (всегда из rs2)

  input  logic        irq_req_i,
  output logic        irq_ret_o   // Сигнал, что возврат из прерывания выполнен
);

  logic [31:0] a_i;     
  logic [31:0] b_i;   
  logic [31:0] alu_result; 
  logic alu_flag;    

  logic ill_instr;   
  logic irq;    
  logic trap;
  
  assign trap = irq | ill_instr;

  logic [1:0] a_sel;   
  logic [2:0] b_sel;   
  logic [1:0] wb_sel;    
  logic [4:0] alu_op;   
  logic gpr_we;  
  
  logic branch;     
  logic jal;        
  logic jalr; 
  logic mret;  // инструкция возврата из прерывания (mret)

  logic mem_req;   // нужно обратиться к памяти
  logic mem_we;          // 1 - запись, 0 - чтение

  logic [2:0] csr_op;    // Код операции CSR
  logic csr_we;     // Разрешение записи в CSR
  
  
  logic [31:0] csr_wd;       
  logic [31:0] mie;      
  logic [31:0] irq_cause;    // Код причины прерывания
  logic [31:0] mcause;       // Код причины исключения/прерывания

  logic [31:0] rd1;      
  logic [31:0] rd2;      
  logic [31:0] wb_data;  
  logic we; 

  logic [31:0] PC;  
  logic [31:0] next_PC;    
  always_ff @(posedge clk_i) begin
    if(~stall_i) begin
      if (rst_i == 1) PC <= 32'd0;
      else PC <= next_PC;
    end
  end

  import decoder_pkg::*;

  logic [31:0] imm_I;  // I-тип 
  logic [31:0] imm_U; // U-тип  20 бит
  logic [31:0] imm_S;   // S-тип 12 бит
  logic [31:0] imm_B; // B-тип 13 бит 
  logic [31:0] imm_J;  // J-тип (jal) 21 бит 
  logic [31:0] imm_Z;   // Z-тип (CSR-инструкции) 5 бит

  assign imm_I = {{20{instr_i[31]}}, instr_i[31:20]};
  assign imm_U = {instr_i[31:12], 12'h000};
  assign imm_S = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
  assign imm_B = {{19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
  assign imm_J = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
  assign imm_Z = {27'd0, instr_i[19:15]};
  
  assign we = ~(trap | stall_i) ;

  register_file register(
    .clk_i(clk_i),
    .write_enable_i(we),
    .write_addr_i(instr_i[11:7]),      // rd
    .read_addr1_i(instr_i[19:15]),     // rs1
    .read_addr2_i(instr_i[24:20]),     // rs2
    .write_data_i(wb_data),
    .read_data1_o(rd1),
    .read_data2_o(rd2)
  );
  
  
  always_comb begin
    case(a_sel)
      OP_A_RS1:     a_i = rd1; // из регистра rs1
      OP_A_CURR_PC: a_i = PC;   // нужен для auipc, jalr
      OP_A_ZERO:    a_i = 32'd0;
      default:      a_i = 32'd0;
    endcase
  end

  always_comb begin
    case(b_sel)
      OP_B_RS2:     b_i = rd2;   // Из регистра rs2
      OP_B_IMM_I:   b_i = imm_I; 
      OP_B_IMM_U:   b_i = imm_U; 
      OP_B_IMM_S:   b_i = imm_S; 
      OP_B_INCR:    b_i = 32'd4;  // Константа 4 (для PC+4)
      default:      b_i = 32'd0;
    endcase
  end

// определяем правильный - нужный нам источник для записи в регистр
  always_comb begin
    case(wb_sel)
      WB_EX_RESULT: wb_data = alu_result;  
      WB_LSU_DATA:  wb_data = mem_rd_i;   
      WB_CSR_DATA:  wb_data = csr_wd;     
      default:      wb_data = alu_result;
    endcase
  end

  decoder main_decoder(
    .fetched_instr_i(instr_i),
    .a_sel_o(a_sel),
    .b_sel_o(b_sel),
    .alu_op_o(alu_op),
    .csr_op_o(csr_op),
    .csr_we_o(csr_we),
    .mem_req_o(mem_req),
    .mem_we_o(mem_we),
    .mem_size_o(mem_size_o),
    .gpr_we_o(gpr_we),
    .wb_sel_o(wb_sel),
    .illegal_instr_o(ill_instr),
    .branch_o(branch), .jal_o(jal), .jalr_o(jalr), .mret_o(mret)
  );


  alu ALU(
    .a_i(a_i),
    .b_i(b_i),
    .alu_op_i(alu_op),
    .flag_o(alu_flag),
    .result_o(alu_result)
  );


// переходы
  logic [31:0] b_or_j;    
  logic [31:0] jb_or_4;  // Выбор между смещением перехода и +4
  logic [31:0] bj4_sum;  // PC + jb_or_4
  logic [31:0] jalr_sum;     // rd1 + imm_I (для jalr)
  logic [31:0] jalr_or_bj4;  // Выбор между jalr_sum и bj4_sum
  logic [31:0] jalr_or_bj4_or_mtvec; // Ещё выбор: переход или вектор прерывания
  logic [31:0] mtvec; // Адрес обработчика прерываний (из CSR)
  logic [31:0] mepc;  // Адрес возврата из прерывания (из CSR)

  // Для условного перехода используем imm_B, для jal - imm_J
  assign b_or_j = branch ? imm_B : imm_J;
  
  // Если условие ветвления выполнено (alu_flag & branch) или это jal - берём смещение, иначе +4
  assign jb_or_4 = ((alu_flag & branch) | jal) ? b_or_j : 32'd4;

  
  // Для jalr обнуляем младший бит (требование RISC-V - адрес должен быть чётным)
  assign jalr_or_bj4 = jalr ? {jalr_sum[31:1], 1'b0} : bj4_sum;

  // При возникновении trap (исключение или прерывание) переходим на mtvec
  assign jalr_or_bj4_or_mtvec = trap ? mtvec : jalr_or_bj4;

  // При инструкции mret восстанавливаем PC из mepc (возврат из прерывания)
  assign next_PC = mret ? mepc : jalr_or_bj4_or_mtvec;
    
  csr_controller control_status_registers(
    .clk_i(clk_i), .rst_i(rst_i), .trap_i(trap), .opcode_i(csr_op),
    .addr_i(instr_i[31:20]), .pc_i(PC), .mcause_i(mcause),
    .rs1_data_i(rd1), .imm_data_i(imm_Z), .write_enable_i(csr_we),
    .read_data_o(csr_wd), .mie_o(mie), .mepc_o(mepc), .mtvec_o(mtvec)
  );

  fulladder32 adder32_bj(
  .a_i(PC),
  .b_i(jb_or_4),
  .carry_i(1'b0),
  .sum_o(bj4_sum),
  .carry_o() 
  );
  
  fulladder32 adder32_jalr(
  .a_i(rd1),
  .b_i(imm_I),
  .carry_i(1'b0),
  .sum_o(jalr_sum),
  .carry_o() );

  assign mem_wd_o   = rd2;               // Данные для записи в память - всегда из rs2
  assign mem_addr_o = alu_result;        // Адрес для памяти данных - результат АЛУ (база + смещение)
  assign instr_addr_o = PC;              // Адрес инструкции - просто текущий PC
  
  assign mem_req_o = ~trap & mem_req;
  assign mem_we_o  = ~trap & mem_we;


  // При illegal instruction код причины = 2 (стандарт RISC-V), иначе - код от irq_controller
  assign mcause = ill_instr ? 32'h0000_0002 : irq_cause;

endmodule

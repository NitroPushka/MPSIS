module processor_core (
  input  logic        clk_i,          // тактовый сигнал
  input  logic        rst_i,          // сброс (1 – начать с нуля)
  input  logic        stall_i,        // заморозка (1 – не двигать PC, не писать в регистры)
  input  logic [31:0] instr_i,        // инструкция из памяти
  input  logic [31:0] mem_rd_i,       // данные, прочитанные из памяти данных
  input  logic        irq_req_i,      // запрос прерывания (1 – нужно обработать)

  output logic [31:0] instr_addr_o,   // адрес инструкции (на выход к памяти)
  output logic [31:0] mem_addr_o,     // адрес для памяти данных
  output logic [ 2:0] mem_size_o,     // размер доступа: 0-байт,1-полуслово,2-слово
  output logic        mem_req_o,      // запрос к памяти данных
  output logic        mem_we_o,       // 1 – запись, 0 – чтение
  output logic [31:0] mem_wd_o,       // данные для записи в память
  output logic        irq_ret_o       // сигнал возврата из прерывания
);

  // Генерация констант из инструкции (I, U, S, B, J, Z типы)
  logic [31:0] imm_I, imm_U, imm_S, imm_B, imm_J, imm_Z;
  assign imm_I = {{20{instr_i[31]}}, instr_i[31:20]};
  assign imm_U = {instr_i[31:12], 12'h000};
  assign imm_S = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
  assign imm_B = {{19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
  assign imm_J = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
  assign imm_Z = {27'd0, instr_i[19:15]};

  // Сигналы управления от декодера
  logic [1:0] a_sel;          // выбор первого операнда АЛУ
  logic [2:0] b_sel;          // выбор второго операнда АЛУ
  logic [1:0] wb_sel;         // выбор источника данных для записи в регистры
  logic [4:0] alu_op;         // операция АЛУ
  logic gpr_we;               // разрешение записи в регистровый файл
  logic branch, jal, jalr;    // типы переходов
  logic mret;                 // возврат из прерывания
  logic ill_instr;            // недопустимая инструкция

  // Прерывания
  logic irq, trap;
  assign trap = irq | ill_instr;   // любое исключение или прерывание

  // Регистровый файл (32 регистра)
  logic [31:0] rd1, rd2, wb_data;
  logic we = ~(trap | stall_i) & gpr_we;  // запись разрешена, если нет trap/stall

  // АЛУ
  logic [31:0] a_i, b_i, alu_result;
  logic alu_flag;   // флаг сравнения (нужен для условных переходов)

  // Мультиплексоры операндов АЛУ
  always_comb case(a_sel)
    OP_A_RS1:     a_i = rd1;        // из регистра rs1
    OP_A_CURR_PC: a_i = PC;         // текущий PC (для auipc, jalr)
    OP_A_ZERO:    a_i = 32'd0;
  endcase
  always_comb case(b_sel)
    OP_B_RS2:     b_i = rd2;        // из регистра rs2
    OP_B_IMM_I:   b_i = imm_I;      // константа I-типа
    OP_B_IMM_U:   b_i = imm_U;      // U-типа
    OP_B_IMM_S:   b_i = imm_S;      // S-типа
    OP_B_INCR:    b_i = 32'd4;      // +4
  endcase

  // Мультиплексор обратной записи (что писать в регистр)
  always_comb case(wb_sel)
    WB_EX_RESULT: wb_data = alu_result; // результат АЛУ
    WB_LSU_DATA:  wb_data = mem_rd_i;   // данные из памяти (load)
    WB_CSR_DATA:  wb_data = csr_wd;     // данные из CSR
  endcase

  // Логика счётчика команд (PC)
  logic [31:0] PC, next_PC;
  logic [31:0] b_or_j, jb_or_4, bj4_sum, jalr_sum, jalr_or_bj4;
  logic [31:0] jalr_or_bj4_or_mtvec, mtvec, mepc;

  assign b_or_j = branch ? imm_B : imm_J;
  assign jb_or_4 = ((alu_flag & branch) | jal) ? b_or_j : 32'd4;
  fulladder32 adder_bj(.a_i(PC), .b_i(jb_or_4), .sum_o(bj4_sum));
  fulladder32 adder_jalr(.a_i(rd1), .b_i(imm_I), .sum_o(jalr_sum));
  assign jalr_or_bj4 = jalr ? {jalr_sum[31:1],1'b0} : bj4_sum;
  assign jalr_or_bj4_or_mtvec = trap ? mtvec : jalr_or_bj4;
  assign next_PC = mret ? mepc : jalr_or_bj4_or_mtvec;

  // Регистр PC (обновляется, если нет stall)
  always_ff @(posedge clk_i) if(~stall_i) PC <= rst_i ? 32'd0 : next_PC;

  // Выходы к памяти и LSU
  assign instr_addr_o = PC;
  assign mem_wd_o = rd2;
  assign mem_addr_o = alu_result;
  assign mem_req_o = ~trap & mem_req;
  assign mem_we_o  = ~trap & mem_we;

  // CSR и контроллер прерываний (встроены в ядро)
  csr_controller csr(...);         // хранит mtvec, mepc, mcause и др.
  interrupt_controller irq_ctrl(...); // превращает irq_req_i в irq

  // Декодер и готовые блоки
  decoder dec(...);
  register_file rf(...);
  alu alu_inst(...);
endmodule

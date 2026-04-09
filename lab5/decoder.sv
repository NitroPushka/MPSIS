module decoder (
  input  logic [31:0]  fetched_instr_i,
  
 // мультиплексор
  output logic [1:0]   a_sel_o, // выбор операнда АЛУ вход А
  output logic [2:0]   b_sel_o,
  
 // АЛУ
  output logic [4:0]   alu_op_o,
 
 // Система
  output logic [2:0]   csr_op_o, // сигнал управление регистрами настроек (ЧТО СДЕЛАТЬ)
  output logic         csr_we_o, // разрешение записи
  
 // Память данных
  output logic         mem_req_o, // запрос к памяти для загрузки и сохранения
  output logic         mem_we_o,  // направление 1 - записиь, 0 - чтение
  output logic [2:0]   mem_size_o, // размер
  
 // Регистровый файл
  output logic         gpr_we_o, // разрешение запись в рег.файл в регистр рд
  output logic [1:0]   wb_sel_o, // выбор источника данных для записи
  
// Блоки управления Программ каунтер
  output logic         illegal_instr_o,
  output logic         branch_o,
  output logic         jal_o,
  output logic         jalr_o, // безусловный переход через регистр (использует значение из регистра И-тип)
  output logic         mret_o // возврат из прерывания
);

  import decoder_pkg::*;
  import alu_opcodes_pkg::*;
  import csr_pkg::*;

  logic [6:0] opcode; // группа инструкции
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [4:0] rd; // регистр назначения

  assign opcode = fetched_instr_i[6:0];
  assign funct3 = fetched_instr_i[14:12];
  assign funct7 = fetched_instr_i[31:25];
  assign rd     = fetched_instr_i[11:7];

  always_comb begin
    a_sel_o      = OP_A_ZERO; // 0
    b_sel_o      = OP_B_INCR; // конст. 4
    alu_op_o     = ALU_ADD;
    csr_op_o     = 1'b0; // нет системных инструкции
    csr_we_o     = 1'b0;
    mem_req_o    = 1'b0;
    mem_we_o     = 1'b0;
    mem_size_o   = LDST_W; // размер слова
    gpr_we_o     = 1'b0;
    wb_sel_o     = WB_EX_RESULT;
    branch_o     = 1'b0;
    jal_o        = 1'b0;
    jalr_o       = 1'b0;
    mret_o       = 1'b0;
    illegal_instr_o = 1'b0;
       
  // проверяем чтобы младшие биты были 11
    if (fetched_instr_i[1:0] != 2'b11) begin
      illegal_instr_o = 1'b1;
    end else begin
      case (opcode[6:2])
      
      // Р-тип
        OP_OPCODE: begin
          a_sel_o = OP_A_RS1;
          b_sel_o = OP_B_RS2;
          gpr_we_o = 1'b1; // разрешение в регистровый файл
          wb_sel_o = WB_EX_RESULT; // результат берем из АЛУ
          case (funct3)
            3'b000: begin 
                    if (funct7 == 7'b0000000) alu_op_o = ALU_ADD;
                    else if (funct7 == 7'b0100000) alu_op_o = ALU_SUB;
                    else begin 
                    illegal_instr_o = 1'b1;
                    gpr_we_o = 1'b0;
                    end
                   end
            3'b001: begin
                if (funct7 == 7'b0000000) alu_op_o = ALU_SLL;
                                    else begin 
                    illegal_instr_o = 1'b1;
                    gpr_we_o = 1'b0;
                    end
            end
            3'b010: 
            begin
                if (funct7 == 7'b0000000) alu_op_o = ALU_SLTS;
                                    else begin 
                    illegal_instr_o = 1'b1;
                    gpr_we_o = 1'b0;
                    end
            end
            3'b011: begin
                if (funct7 == 7'b0000000) alu_op_o = ALU_SLTU;
                                    else begin 
                    illegal_instr_o = 1'b1;
                    gpr_we_o = 1'b0;
                    end
            end

            3'b100: begin
                if (funct7 == 7'b0000000) alu_op_o = ALU_XOR;
                                    else begin 
                    illegal_instr_o = 1'b1;
                    gpr_we_o = 1'b0;
                    end
            end
            3'b101: begin
                if (funct7 == 7'b0000000) alu_op_o = ALU_SRL;
                else if (funct7 == 7'b0100000) alu_op_o = ALU_SRA;
                                    else begin 
                    illegal_instr_o = 1'b1;
                    gpr_we_o = 1'b0;
                    end
            end
            3'b110: begin
                if (funct7 == 7'b0000000) alu_op_o = ALU_OR;
                                    else begin 
                    illegal_instr_o = 1'b1;
                    gpr_we_o = 1'b0;
                    end
            end
           
            3'b111: begin
                if (funct7 == 7'b0000000) alu_op_o = ALU_AND;
                                    else begin 
                    illegal_instr_o = 1'b1;
                    gpr_we_o = 1'b0;
                    end
                end
            default: begin
             illegal_instr_o = 1'b1;
             gpr_we_o = 1'b0;
             end
          endcase
        end
        
       // И - тип
        OP_IMM_OPCODE: begin
          a_sel_o = OP_A_RS1;
          b_sel_o = OP_B_IMM_I; // непосредственная конст.
          gpr_we_o = 1'b1;
          wb_sel_o = WB_EX_RESULT;
          case (funct3)
            3'b000: alu_op_o = ALU_ADD;
            3'b010: alu_op_o = ALU_SLTS;
            3'b011: alu_op_o = ALU_SLTU;
            3'b100: alu_op_o = ALU_XOR;
            3'b110: alu_op_o = ALU_OR;
            3'b111: alu_op_o = ALU_AND;
            3'b001: begin
              if (funct7 == 7'b0000000) alu_op_o = ALU_SLL; // сдвиг влево на конст. старшие 7 бит должны быть нулями для сдвига
              else begin 
              illegal_instr_o = 1'b1;
              gpr_we_o = 1'b0;
             end
            end
            3'b101: begin
              if (funct7 == 7'b0000000) alu_op_o = ALU_SRL; // аналогично, только свдиг вправо
              else if (funct7 == 7'b0100000) alu_op_o = ALU_SRA; // арифметический сдвиг
              else begin 
              illegal_instr_o = 1'b1;
              gpr_we_o = 1'b0;
             end
            end
            default:begin
             illegal_instr_o = 1'b1;
             gpr_we_o = 1'b1;
             end
          endcase
        end
      
      // Загрузка из памяти = Вычисляем адрес памяти, читаем из памяти по адресу, записываем в регистр рд, размер чтения зависит от функт3
        LOAD_OPCODE: begin
          a_sel_o = OP_A_RS1;
          b_sel_o = OP_B_IMM_I;
          alu_op_o = ALU_ADD; // адрес = рс1 + смещение имм
          mem_req_o = 1'b1;
          mem_we_o = 1'b0; // чтение
          gpr_we_o = 1'b1;
          wb_sel_o = WB_LSU_DATA;
          case (funct3)
            3'b000: mem_size_o = LDST_B; // байт со знаком
            3'b001: mem_size_o = LDST_H; // полуслово со знаком
            3'b010: mem_size_o = LDST_W; // слово 32 бита
            3'b100: mem_size_o = LDST_BU; // байт без знака
            3'b101: mem_size_o = LDST_HU; // полуслово без знака
            default: begin
            illegal_instr_o = 1'b1;
            mem_req_o = 1'b0;
            gpr_we_o = 1'b0;
            end
          endcase
        end
       
      // запись в память - в оперативную память, который вычисляется по адресу через алу, а регистр не меняется
        STORE_OPCODE: begin
          a_sel_o = OP_A_RS1; // базовый адрес
          b_sel_o = OP_B_IMM_S; // смещение
          alu_op_o = ALU_ADD;
          gpr_we_o = 0; // не пишем в регистровый файл
          mem_req_o = 1'b1; // обращение к памяти
          mem_we_o = 1'b1; // пишем
          case (funct3)
            3'b000: mem_size_o = LDST_B; // байт
            3'b001: mem_size_o = LDST_H; // полуслово 16 бит - сжатый
            3'b010: mem_size_o = LDST_W; // слово
            default: begin
            illegal_instr_o = 1'b1;
            mem_req_o = 1'b0;
            gpr_we_o = 1'b0;
            mem_we_o = 1'b0;
            end
          endcase
        end
   // условный переход
        BRANCH_OPCODE: begin
          a_sel_o = OP_A_RS1;
          b_sel_o = OP_B_RS2;
          branch_o = 1'b1; // йоу, условный переход
          case (funct3)
            3'b000: alu_op_o = ALU_EQ; // равно
            3'b001: alu_op_o = ALU_NE; // неравно 
            3'b100: alu_op_o = ALU_LTS; // меньше(знаковое)
            3'b101: alu_op_o = ALU_GES; // больше или равно (знаковое)
            3'b110: alu_op_o = ALU_LTU; // меньше (беззнаковое)
            3'b111: alu_op_o = ALU_GEU; // больше или равно(беззнаковое)
            default: begin 
            illegal_instr_o = 1'b1;
            branch_o = 1'b0;
            end
          endcase
        end

        // безусловный переход с сохранением адреса
        JAL_OPCODE: begin
          a_sel_o = 1'b1;
          jal_o = 1'b1;
          gpr_we_o = 1'b1;
        end

        JALR_OPCODE: begin
        if (funct3 == 3'b000) begin
              jalr_o = 1'b1;
              gpr_we_o = 1'b1;
              a_sel_o = OP_A_CURR_PC;
              b_sel_o = OP_B_INCR;
              alu_op_o = ALU_ADD; // адрес перехода \
          end else begin
                illegal_instr_o = 1'b1;
                gpr_we_o = 1'b0;
                jalr_o = 1'b0;
              end
        end
       
       // загрузка верхней части - расширяем кол-во битов до 32
       
       // формируется 32 битная константа (младшие 12 бит нули) это константа пишется в регистр рд
        LUI_OPCODE: begin
          a_sel_o = OP_A_ZERO; // 0
          b_sel_o = OP_B_IMM_U; // У тип (20 бит) константа в старшие биты
          alu_op_o = ALU_ADD; // увеличиваем до 32 0 + (имм влево 12)
          gpr_we_o = 1'b1; // пишем в регистр
          wb_sel_o = WB_EX_RESULT; // берём результат из АЛУ
        end
    
      // прибавить имм к программ каунтер
        AUIPC_OPCODE: begin
          a_sel_o = OP_A_CURR_PC; // первый операнд
          b_sel_o = OP_B_IMM_U; // имм У-ти
          alu_op_o = ALU_ADD; // добавляем к программ каунтеру 32битную (джамп и бранч не хватит)
          gpr_we_o = 1'b1;
          wb_sel_o = WB_EX_RESULT;
        end

    // система инструкции
        SYSTEM_OPCODE: begin
          case (funct3)
            3'b000: begin // еколл, ебрик, мрет
              if (fetched_instr_i == 32'h00000073) begin
                illegal_instr_o = 1'b1; // еколл
              end else if (fetched_instr_i == 32'h00100073) begin
                illegal_instr_o = 1'b1; // ебрик
              end else if (fetched_instr_i == 32'h30200073) begin
                mret_o = 1'b1; // мрет
              end else begin
                illegal_instr_o = 1'b1;
              end
            end
            
          // системные инструкции (функт от 1 до 6)
            3'b001, 3'b010, 3'b011, 3'b101, 3'b110, 3'b111: begin
              csr_we_o = 1'b1; // разрешение запись 
              gpr_we_o = 1'b1; // разрешаем запись в регистр (читаем старое значение)
              wb_sel_o = WB_CSR_DATA; // источник для регистра
              case (funct3)
                3'b001: csr_op_o = CSR_RW;
                3'b010: csr_op_o = CSR_RS;
                3'b011: csr_op_o = CSR_RC;
                3'b101: csr_op_o = CSR_RWI;
                3'b110: csr_op_o = CSR_RSI;
                3'b111: csr_op_o = CSR_RCI;
                default: csr_op_o = 1'b0;
              endcase
            end
            default: illegal_instr_o = 1'b1;
          endcase
        end
    
    // барьер памяти
        MISC_MEM_OPCODE: begin
          if (funct3 != 3'b000) illegal_instr_o = 1'b1;
        end

        default: illegal_instr_o = 1'b1;
      endcase
    end
  end

endmodule

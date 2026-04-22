// Преобразует запрос ядра в запрос к синхронной памяти данных
module lsu (
  input  logic        clk_i, rst_i,
  // Интерфейс с ядром
  input  logic        core_req_i,      // запрос от ядра
  input  logic        core_we_i,       // 1 – запись, 0 – чтение
  input  logic [2:0]  core_size_i,     // 0:байт, 1:полуслово, 2:слово
  input  logic [31:0] core_addr_i,     // адрес (байтовый)
  input  logic [31:0] core_wd_i,       // данные для записи
  output logic [31:0] core_rd_o,       // прочитанные данные (на следующий такт)
  output logic        core_stall_o,    // 1 – ядро должно ждать

  // Интерфейс с памятью данных
  output logic        mem_req_o,       // запрос к памяти
  output logic        mem_we_o,        // запись/чтение
  output logic [3:0]  mem_be_o,        // маска байтов (byte enable)
  output logic [31:0] mem_addr_o,      // адрес слова в памяти
  output logic [31:0] mem_wd_o,        // данные для записи
  input  logic [31:0] mem_rd_i,        // данные из памяти
  input  logic        mem_ready_i      // память всегда готова
);
  // Состояния: IDLE – ждём запрос, BUSY – обрабатываем
  enum logic { IDLE, BUSY } state;

  // Регистры для хранения запроса (защёлкиваем в IDLE)
  logic        req_r, we_r;
  logic [2:0]  size_r;
  logic [31:0] addr_r, wdata_r;

  // Формирование маски байтов по адресу и размеру (пример для слова, полуслова, байта)
  logic [3:0] be;
  always_comb begin
    case (size_r)
      2: be = 4'b1111;                                 // слово
      1: be = (addr_r[1]) ? 4'b1100 : 4'b0011;        // полуслово
      0: begin                                         // байт
        case (addr_r[1:0])
          2'b00: be = 4'b0001;
          2'b01: be = 4'b0010;
          2'b10: be = 4'b0100;
          2'b11: be = 4'b1000;
        endcase
      end
      default: be = 4'b0000;
    endcase
  end

  // Конечный автомат
  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) state <= IDLE;
    else case (state)
      IDLE: if (core_req_i) begin
        req_r <= 1; we_r <= core_we_i; size_r <= core_size_i;
        addr_r <= core_addr_i; wdata_r <= core_wd_i;
        state <= BUSY;
      end
      BUSY: begin
        req_r <= 0;   // один такт – запрос обработан
        state <= IDLE;
      end
    endcase
  end

  // Защёлка результата чтения (синхронно)
  logic [31:0] rd_r;
  always_ff @(posedge clk_i) if (state == BUSY && !we_r) rd_r <= mem_rd_i;
  assign core_rd_o = rd_r;

  // Выходы на память
  assign mem_req_o = req_r;
  assign mem_we_o  = we_r;
  assign mem_be_o  = be;
  assign mem_addr_o = {addr_r[31:2], 2'b00}; // выравнивание до границы слова
  assign mem_wd_o  = wdata_r;

  // Сигнал заморозки ядра: занят, пока не вернём результат
  assign core_stall_o = (state == BUSY);
endmodule

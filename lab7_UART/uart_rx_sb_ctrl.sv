module uart_rx_sb_ctrl(
/*
    Часть интерфейса модуля, отвечающая за подключение к системной шине
*/
  input  logic          clk_i,
  input  logic          rst_i,
  input  logic [31:0]   addr_i,
  input  logic          req_i,
  input  logic [31:0]   write_data_i,
  input  logic          write_enable_i,
  output logic [31:0]   read_data_o,

/*
    Часть интерфейса модуля, отвечающая за отправку запросов на прерывание
    процессорного ядра
*/

  output logic        interrupt_request_o,
  input  logic        interrupt_return_i,

/*
    Часть интерфейса модуля, отвечающая за подключение передающему,
    входные данные по UART
*/
  input  logic          rx_i
);

  logic busy;
  logic [16:0] baudrate;
  logic parity_en;
  logic [1:0]  stopbit;
  logic [7:0]  data;
  
  // Есть ли новые, ещё не прочитанные данные
  logic valid;
  
  // сигналы от uart_rx
  logic        uart_busy;
  logic [7:0]  uart_data;
  logic        uart_valid;
  logic        read_data_req;
  
  
  
uart_rx uart_rx_inst (
    .clk_i, .rst_i,
    .rx_i,               // физический вход
    .busy_o,            // идёт приём
    .baudrate_i,        // делитель скорости
    .parity_en_i,       // контроль чётности
    .stopbit_i,         // стоп-биты
    .rx_data_o,         // принятый байт
    .rx_valid_o         // импульс: данные готовы
);

logic uart_reset;
// аппаратный сброс ИЛИ программный сброс - если идет запись и адрес равнев 24 и данные равны 1
assign uart_reset = rst_i || (req_i && write_enable_i && addr_i == 32'h0000_0024 && write_data_i == 32'd1);

// флаг, который говорит: «процессор только что прочитал принятый байт - процессор обращается именно к моей переферии, это чтение, а не запись, читается именно регистр данных
assign read_data_req = req_i && !write_enable_i && (addr_i == 32'h0000_0000);

//  линия прерывания, которая идёт от UART к процессору.
assign interrupt_request_o = valid;

always_ff @(posedge clk_i) begin
    if (uart_reset) begin
      busy      <= 1'b0;
      baudrate  <= 17'd9600;
      parity_en <= 1'b0;
      stopbit   <= 2'd1;
      data      <= 8'd0;
      valid     <= 1'b0;
    end else begin
    
    // Выходной сигнал busy на каждом такте clk_i должен записываться в регистр busy доступ на чтение к которому осуществляется по адресу 0x08
      busy <= uart_busy;
    // busy, сообщающего о том, что модуль находится в процессе передачи данных
      if (!uart_busy && req_i && write_enable_i) begin
        case (addr_i)
          32'h0000_000C:  baudrate  <= write_data_i[16:0];
          32'h0000_0010:  parity_en <= write_data_i[0];
          32'h0000_0014:  stopbit   <= write_data_i[1:0];
          default: begin end
        endcase
      end

      if (read_data_req || interrupt_return_i) begin
        valid <= 1'b0;
      end

      if (uart_valid) begin
        data  <= uart_data;
        valid <= 1'b1;
      end
    end
  end


endmodule
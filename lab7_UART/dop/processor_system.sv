module processor_system(
  input  logic        clk_i,
  input  logic        resetn_i,

  input  logic [15:0] sw_i,
  output logic [15:0] led_o,

  input  logic        kclk_i,
  input  logic        kdata_i,

  output logic [ 6:0] hex_led_o,
  output logic [ 7:0] hex_sel_o,

  input  logic        rx_i,
  output logic        tx_o,

  output logic [3:0]  vga_r_o,
  output logic [3:0]  vga_g_o,
  output logic [3:0]  vga_b_o,
  output logic        vga_hs_o,
  output logic        vga_vs_o
);

  import peripheral_pkg::*;

  logic sysclk, rst;

  // Сигналы для LSU
  logic        core_req;
  logic        core_we;
  logic [2:0]  core_size;
  logic [31:0] core_addr;
  logic [31:0] core_wd;
  logic [31:0] core_rd;
  logic        core_stall;

  // Сигналы для системной шины
  logic        mem_req;
  logic        mem_we;
  logic [3:0]  mem_be;
  logic [31:0] mem_addr;
  logic [31:0] mem_wd;
  logic [31:0] mem_rd;
  logic        mem_ready;

  // Сигналы для прерываний
  logic        irq_req;
  logic        irq_ret;

  // Сигналы для памяти инструкций
  logic [31:0] instr_addr;
  logic [31:0] instr;

  // Сигналы для памяти данных и UART-контроллеров
  logic        dmem_req;
  logic        uart_rx_req;
  logic        uart_tx_req;
  logic [31:0] periph_addr;
  logic [31:0] dmem_rd;
  logic [31:0] uart_rx_rd;
  logic [31:0] uart_tx_rd;

  // Делитель частоты и преобразователь сброса
  sys_clk_rst_gen divider(
    .ex_clk_i(clk_i),
    .ex_areset_n_i(resetn_i),
    .div_i(5),
    .sys_clk_o(sysclk),
    .sys_reset_o(rst)
  );

  // Выбор устройства по старшим 8 битам адреса
  assign mem_ready = 1'b1;
  assign dmem_req    = mem_req && (mem_addr[31:24] == DMEM_ADDR_HIGH);
  assign uart_rx_req = mem_req && (mem_addr[31:24] == RX_ADDR_HIGH);
  assign uart_tx_req = mem_req && (mem_addr[31:24] == TX_ADDR_HIGH);
  assign periph_addr[31:24] = 8'd0;
  assign periph_addr[23:0]  = mem_addr[23:0];

  // Нереализованная периферия пока отключена
  assign led_o     = 16'd0;
  assign hex_led_o = 7'h7f;
  assign hex_sel_o = 8'hff;
  assign vga_r_o   = 4'd0;
  assign vga_g_o   = 4'd0;
  assign vga_b_o   = 4'd0;
  assign vga_hs_o  = 1'b0;
  assign vga_vs_o  = 1'b0;

  processor_core core (
    .clk_i(sysclk),
    .rst_i(rst),
    .stall_i(core_stall),
    .instr_i(instr),
    .mem_rd_i(core_rd),
    .irq_req_i(irq_req),
    .instr_addr_o(instr_addr),
    .mem_addr_o(core_addr),
    .mem_size_o(core_size),
    .mem_req_o(core_req),
    .mem_we_o(core_we),
    .mem_wd_o(core_wd),
    .irq_ret_o(irq_ret)
  );

  instr_mem imem (
    .read_addr_i(instr_addr),
    .read_data_o(instr)
  );

  // LSU
  lsu lsu_inst (
    .clk_i(sysclk),
    .rst_i(rst),
    .core_req_i(core_req),
    .core_we_i(core_we),
    .core_size_i(core_size),
    .core_addr_i(core_addr),
    .core_wd_i(core_wd),
    .core_rd_o(core_rd),
    .core_stall_o(core_stall),
    .mem_req_o(mem_req),
    .mem_we_o(mem_we),
    .mem_be_o(mem_be),
    .mem_addr_o(mem_addr),
    .mem_wd_o(mem_wd),
    .mem_rd_i(mem_rd),
    .mem_ready_i(mem_ready)
  );

  // Память данных
  data_mem dmem (
    .clk_i(sysclk),
    .mem_req_i(dmem_req),
    .write_enable_i(mem_we),
    .byte_enable_i(mem_be),
    .addr_i(mem_addr),
    .write_data_i(mem_wd),
    .read_data_o(dmem_rd),
    .ready_o()
  );

  // Контроллер UART RX
  uart_rx_sb_ctrl uart_rx_ctrl (
    .clk_i(sysclk),
    .rst_i(rst),
    .addr_i(periph_addr),
    .req_i(uart_rx_req),
    .write_data_i(mem_wd),
    .write_enable_i(mem_we),
    .read_data_o(uart_rx_rd),
    .interrupt_request_o(irq_req),
    .interrupt_return_i(irq_ret),
    .rx_i(rx_i)
  );

  // Контроллер UART TX
  uart_tx_sb_ctrl uart_tx_ctrl (
    .clk_i(sysclk),
    .rst_i(rst),
    .addr_i(periph_addr),
    .req_i(uart_tx_req),
    .write_data_i(mem_wd),
    .write_enable_i(mem_we),
    .read_data_o(uart_tx_rd),
    .tx_o(tx_o)
  );

  always_comb begin
    case (mem_addr[31:24])
      DMEM_ADDR_HIGH: mem_rd = dmem_rd;
      RX_ADDR_HIGH:   mem_rd = uart_rx_rd;
      TX_ADDR_HIGH:   mem_rd = uart_tx_rd;
      default:        mem_rd = 32'd0;
    endcase
  end

endmodule

module uart_rx_sb_ctrl(
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic [31:0] addr_i,
  input  logic        req_i,
  input  logic [31:0] write_data_i,
  input  logic        write_enable_i,
  output logic [31:0] read_data_o,

  output logic        interrupt_request_o,
  input  logic        interrupt_return_i,

  input  logic        rx_i
);

  logic        busy;
  logic [16:0] baudrate;
  logic        parity_en;
  logic [1:0]  stopbit;
  logic [7:0]  data;
  logic        valid;

  logic        uart_busy;
  logic [7:0]  uart_data;
  logic        uart_valid;
  logic        uart_reset;
  logic        read_data_req;

 always_ff @(posedge clk_i) begin
    if (uart_reset) begin
      busy      <= 1'b0;
      baudrate  <= 17'd9600;
      parity_en <= 1'b0;

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

  assign uart_reset          = (req_i && write_enable_i && (addr_i == 32'h0000_0024) && (write_data_i == 32'd1)) || rst_i;
  assign read_data_req       = req_i && !write_enable_i && (addr_i == 32'h0000_0000);
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
      busy <= uart_busy;

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

  always_ff @(posedge clk_i) begin
    if (uart_reset) begin
      read_data_o <= 32'd0;
    end else if (req_i && !write_enable_i) begin
      case (addr_i)
        32'h0000_0000:   read_data_o <= {24'd0, data};
        32'h0000_0004:   read_data_o <= {31'd0, valid};
        32'h0000_0008:   read_data_o <= {31'd0, busy};
        32'h0000_000C:   read_data_o <= {15'd0, baudrate};
        32'h0000_0010:   read_data_o <= {31'd0, parity_en};
        32'h0000_0014:   read_data_o <= {30'd0, stopbit};
        default:         read_data_o <= read_data_o;
      endcase
    end
  end

  uart_rx uart_rx_inst (
    .clk_i(clk_i),
    .rst_i(uart_reset),
    .rx_i(rx_i),
    .busy_o(uart_busy),
    .baudrate_i(baudrate),
    .parity_en_i(parity_en),
    .stopbit_i(stopbit),
    .rx_data_o(uart_data),
    .rx_valid_o(uart_valid)
  );

endmodule

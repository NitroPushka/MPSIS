module uart_tx_sb_ctrl(
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic [31:0] addr_i,
  input  logic        req_i,
  input  logic [31:0] write_data_i,
  input  logic        write_enable_i,
  output logic [31:0] read_data_o,

  output logic        tx_o
);

  logic        busy;
  logic [16:0] baudrate;
  logic        parity_en;
  logic [1:0]  stopbit;
  logic [7:0]  data;

  logic        uart_busy;
  logic        uart_reset;
  logic        write_data_req;
  logic        tx_valid;

  assign uart_reset     = (req_i && write_enable_i && (addr_i == 32'h0000_0024) && (write_data_i == 32'd1)) || rst_i;
  assign write_data_req = req_i && write_enable_i && (addr_i == 32'h0000_0000) && !uart_busy;
  assign tx_valid       = write_data_req;

  always_ff @(posedge clk_i) begin
    if (uart_reset) begin
      busy      <= 1'b0;
      baudrate  <= 17'd9600;
      parity_en <= 1'b0;
      stopbit   <= 2'd1;
      data      <= 8'd0;
    end else begin
      busy <= uart_busy;

      if (write_data_req) begin
        data <= write_data_i[7:0];
      end

      if (!uart_busy && req_i && write_enable_i) begin
        case (addr_i)
          32'h0000_000C:  baudrate  <= write_data_i[16:0];
          32'h0000_0010:  parity_en <= write_data_i[0];
          32'h0000_0014:  stopbit   <= write_data_i[1:0];
          default: begin end
        endcase
      end
    end
  end

  always_ff @(posedge clk_i) begin
    if (uart_reset) begin
      read_data_o <= 32'd0;
    end else if (req_i && !write_enable_i) begin
      case (addr_i)
        32'h0000_0000:   read_data_o <= {24'd0, data};
        32'h0000_0008:   read_data_o <= {31'd0, busy};
        32'h0000_000C:   read_data_o <= {15'd0, baudrate};
        32'h0000_0010:   read_data_o <= {31'd0, parity_en};
        32'h0000_0014:   read_data_o <= {30'd0, stopbit};
        default:         read_data_o <= read_data_o;
      endcase
    end
  end

  uart_tx uart_tx_inst (
    .clk_i(clk_i),
    .rst_i(uart_reset),
    .tx_o(tx_o),
    .busy_o(uart_busy),
    .baudrate_i(baudrate),
    .parity_en_i(parity_en),
    .stopbit_i(stopbit),
    .tx_data_i(write_data_i[7:0]),
    .tx_valid_i(tx_valid)
  );

endmodule

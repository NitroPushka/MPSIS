module register_file (
  input  logic        clk_i,         
  input  logic        write_enable_i, 
  
  input  logic [ 4:0] write_addr_i,
  input  logic [ 4:0] read_addr1_i, 
  input  logic [ 4:0] read_addr2_i, 
    
  input  logic [31:0] write_data_i,   
  output logic [31:0] read_data1_o, 
  output logic [31:0] read_data2_o   
);

  // Внутренняя память: 32 регистра по 32 бита
  logic [31:0] rf_mem [32];

  // Инициализация нулевого регистра нулём
  initial begin
    rf_mem[0] = 32'b0;
  end

  // Асинхронное чтение (два порта)
  // Для этого используем мультиплексор: если адрес == 0, выдаём 0, иначе данные из памяти.
  assign read_data1_o = (read_addr1_i == 5'b0) ? 32'b0 : rf_mem[read_addr1_i];
  assign read_data2_o = (read_addr2_i == 5'b0) ? 32'b0 : rf_mem[read_addr2_i];

  // Синхронная запись (по posedge фронту clk_i)
  always_ff @(posedge clk_i) begin
  if(write_enable_i) begin
  rf_mem[write_addr_i] <= write_data_i;
  end
end  

endmodule
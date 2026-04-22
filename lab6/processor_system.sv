module processor_system(
  input  logic        clk_i,
  input  logic        rst_i
);

  logic[31:0] instr_addr;

  logic[31:0] core_wd;
  logic[31:0] core_addr;
  logic core_we;
  logic core_req;
  logic[2:0] core_size;
  logic[31:0] core_rd;
  
  logic[31:0] mem_rd;
  logic mem_req;
  logic mem_we;
  logic[3:0] mem_be;
  logic[31:0] mem_wd;
  logic[31:0] mem_addr;
  logic mem_ready;

  logic[31:0] instr;

  logic stall;

  logic irq_req;
  logic irq_ret;

  lsu load_store_unit(.clk_i(clk_i), .rst_i(rst_i), 
  // Интерфейс с ядром
  .core_req_i(core_req), .core_we_i(core_we), .core_size_i(core_size), .core_addr_i(core_addr),
  .core_wd_i(core_wd), .core_rd_o(core_rd), .core_stall_o(stall),

  // Интерфейс с памятью
  .mem_req_o(mem_req), .mem_we_o(mem_we), .mem_be_o(mem_be), .mem_addr_o(mem_addr), .mem_wd_o(mem_wd),
  .mem_rd_i(mem_rd), .mem_ready_i(mem_ready)
  );

  processor_core core(.clk_i(clk_i), .rst_i(rst_i), .stall_i(stall), .instr_i(instr), .mem_rd_i(core_rd), .instr_addr_o(instr_addr),
    .mem_addr_o(core_addr), .mem_size_o(core_size), .mem_req_o(core_req), .mem_we_o(core_we), .mem_wd_o(core_wd), 
    .irq_req_i(irq_req), .irq_ret_o(irq_ret));
  
  instr_mem instruction_memory(.read_addr_i(instr_addr), .read_data_o(instr));

  data_mem data_memory(.clk_i(clk_i), .mem_req_i(mem_req), .write_enable_i(mem_we), .byte_enable_i(mem_be), .addr_i(mem_addr),
   .write_data_i(mem_wd), .read_data_o(mem_rd), .ready_o(mem_ready));

endmodule
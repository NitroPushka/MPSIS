module processor_system (
  input  logic clk_i,   // такт
  input  logic rst_i    // сброс
);
  // Сигналы между блоками
  logic [31:0] instr_addr;   // адрес инструкции (от ядра)
  logic [31:0] instr;        // инструкция (из памяти)

  // Интерфейс ядра <-> LSU
  logic [31:0] core_addr, core_wd, core_rd;
  logic        core_req, core_we;
  logic [2:0]  core_size;
  logic        stall;        // сигнал заморозки от LSU

  // Интерфейс LSU <-> память данных
  logic        mem_req, mem_we;
  logic [3:0]  mem_be;       // маска байтов
  logic [31:0] mem_addr, mem_wd, mem_rd;
  logic        mem_ready;    // память всегда готова (1)

  // Прерывания (пока не подключены к источнику)
  logic irq_req, irq_ret;

  // 1. Ядро процессора
  processor_core core (
    .clk_i, .rst_i, .stall_i(stall), .instr_i(instr), .mem_rd_i(core_rd),
    .instr_addr_o(instr_addr),
    .mem_addr_o(core_addr), .mem_size_o(core_size), .mem_req_o(core_req),
    .mem_we_o(core_we), .mem_wd_o(core_wd),
    .irq_req_i(irq_req), .irq_ret_o(irq_ret)
  );

  // 2. Память инструкций (только чтение)
  instr_mem imem (.read_addr_i(instr_addr), .read_data_o(instr));

  // 3. Блок загрузки-сохранения (LSU) – преобразует запрос ядра в запрос к памяти
  lsu load_store_unit (
    .clk_i, .rst_i,
    .core_req_i(core_req), .core_we_i(core_we), .core_size_i(core_size),
    .core_addr_i(core_addr), .core_wd_i(core_wd), .core_rd_o(core_rd),
    .core_stall_o(stall),
    .mem_req_o(mem_req), .mem_we_o(mem_we), .mem_be_o(mem_be),
    .mem_addr_o(mem_addr), .mem_wd_o(mem_wd), .mem_rd_i(mem_rd),
    .mem_ready_i(mem_ready)
  );

  // 4. Память данных (поддерживает побайтовую запись через byte_enable)
  data_mem dmem (
    .clk_i, .mem_req_i(mem_req), .write_enable_i(mem_we),
    .byte_enable_i(mem_be), .addr_i(mem_addr), .write_data_i(mem_wd),
    .read_data_o(mem_rd), .ready_o(mem_ready)
  );
endmodule

module instr_mem
  import memory_pkg::*;  // импортируем параметры из пакета
(
  input  logic [31:0] read_addr_i,   // байтовый адрес от процессора
  output logic [31:0] read_data_o    // считанная команда (32 бита)
);

  // Объявляем память как массив 32-битных слов размером INSTR_MEM_SIZE_WORDS
  logic [31:0] ROM [INSTR_MEM_SIZE_WORDS];

  // Загружаем содержимое из файла program.mem при старте симуляции/синтеза
  initial begin
    $readmemh("program.mem", ROM);
  end

  // Асинхронное чтение: берём нужный индекс слова.
  // Индекс = старшие биты адреса, начиная с бита 2 (отбрасываем 2 младших).
  // $clog2(INSTR_MEM_SIZE_BYTES) даёт число бит, нужное для адресации всего объёма в байтах.
  // Но мы отбрасываем 2 бита, поэтому итоговый диапазон бит:
  // от ( $clog2(INSTR_MEM_SIZE_BYTES)-1 ) до 2.
  assign read_data_o = ROM[read_addr_i[$clog2(INSTR_MEM_SIZE_BYTES)-1 : 2]];

endmodule
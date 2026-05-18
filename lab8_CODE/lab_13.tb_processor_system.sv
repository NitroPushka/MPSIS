/* -----------------------------------------------------------------------------
* Project Name   : Architectures of Processor Systems (APS) lab work
* Organization   : National Research University of Electronic Technology (MIET)
* Department     : Institute of Microdevices and Control Systems
* Author(s)      : Andrei Solodovnikov
* Email(s)       : hepoh@org.miet.ru
* Modified for individual task: UART echo with unit counting
* ------------------------------------------------------------------------------
*/
module lab_13_tb_processor_system();

import peripheral_pkg::*;

// Параметры UART
parameter real CLK_FREQ = 100_000_000.0;   // тактовая частота (100 МГц)
parameter BAUD_RATE = 9600;               // должна совпадать с настройкой в main.c
parameter BIT_PERIOD = int'(CLK_FREQ / BAUD_RATE); // тактов на бит (~10417)

logic clk_i;
logic resetn;
logic rx_i;          // вход UART процессора (со стороны тестбенча)
logic tx_o;          // выход UART процессора

// Неиспользуемые порты, оставляем без изменений (подключаем к 0)
logic [15:0] sw_i;
logic [15:0] led_o;
logic ps2_clk;
logic ps2_dat;
logic [ 6:0] hex_led_o;
logic [ 7:0] hex_sel_o;

// Генерация тактовой частоты 100 МГц
initial clk_i = 0;
always #5ns clk_i = ~clk_i;

// Ограничение времени симуляции (достаточно для нескольких тестов)
initial #20ms $finish();

// Сброс процессора
initial begin
    resetn = 1;
    repeat(20) @(posedge clk_i);
    resetn = 0;
    repeat(20) @(posedge clk_i);
    resetn = 1;
end

// Подключение процессора
processor_system DUT(
    .clk_i    (clk_i    ),
    .resetn_i (resetn   ),
    .sw_i     (sw_i     ),
    .led_o    (led_o    ),
    .kclk_i   (ps2_clk  ),
    .kdata_i  (ps2_dat  ),
    .hex_led_o(hex_led_o),
    .hex_sel_o(hex_sel_o),
    .rx_i     (rx_i     ),
    .tx_o     (tx_o     )
);

// Неиспользуемые входы заземляем
initial begin
    sw_i = '0;
    ps2_clk = 1'b1;
    ps2_dat = 1'b1;
end


task automatic uart_receive_byte(output logic [7:0] data);
    begin
        @(negedge tx_o);                  // ждём стартовый бит
        #(BIT_PERIOD/2);                 // смещаемся к середине первого бита
        for (int i = 0; i < 8; i++) begin
            #(BIT_PERIOD);
            data[i] = tx_o;
        end
        #(BIT_PERIOD);                   // стоповый бит
    end
endtask


initial begin : test_sequence
    // Ждём окончания сброса и инициализации процессора (~1 мс хватит)
    wait(resetn == 1);
    #1ms;


    $display("[%0t] Test 1: send 0x5B, expect 0x1F", $time);
    rx_i = 1'b1;  // по умолчанию линия в высоком уровне
    uart_rx_send_char(8'h5B, BAUD_RATE, rx_i);  // отправляем байт
    begin
        automatic logic [7:0] result;
        uart_receive_byte(result);
        $display("[%0t] Received: 0x%02h", $time, result);
        if (result == 8'h1F)
            $display("[%0t] Test 1 PASS", $time);
        else
            $error("[%0t] Test 1 FAIL: expected 0x1F, got 0x%02h", $time, result);
    end
    #100us; 


    $display("[%0t] Test 2: send 0xFF, expect 0xFF", $time);
    uart_rx_send_char(8'hFF, BAUD_RATE, rx_i);
    begin
        automatic logic [7:0] result;
        uart_receive_byte(result);
        $display("[%0t] Received: 0x%02h", $time, result);
        if (result == 8'hFF)
            $display("[%0t] Test 2 PASS", $time);
        else
            $error("[%0t] Test 2 FAIL: expected 0xFF, got 0x%02h", $time, result);
    end
    #100us;


    $display("[%0t] Test 3: send 0x00, expect 0x00", $time);
    uart_rx_send_char(8'h00, BAUD_RATE, rx_i);
    begin
        automatic logic [7:0] result;
        uart_receive_byte(result);
        $display("[%0t] Received: 0x%02h", $time, result);
        if (result == 8'h00)
            $display("[%0t] Test 3 PASS", $time);
        else
            $error("[%0t] Test 3 FAIL: expected 0x00, got 0x%02h", $time, result);
    end
    #100us;

 
    $display("[%0t] Test 4: send 0xA5, expect 0x0F", $time);
    uart_rx_send_char(8'hA5, BAUD_RATE, rx_i);
    begin
        automatic logic [7:0] result;
        uart_receive_byte(result);
        $display("[%0t] Received: 0x%02h", $time, result);
        if (result == 8'h0F)
            $display("[%0t] Test 4 PASS", $time);
        else
            $error("[%0t] Test 4 FAIL: expected 0x0F, got 0x%02h", $time, result);
    end

    $display("[%0t] All tests completed.", $time);
    $stop;
end

endmodule
/* -----------------------------------------------------------------------------
* Project Name   : Architectures of Processor Systems (APS) lab work
* Organization   : National Research University of Electronic Technology (MIET)
* Department     : Institute of Microdevices and Control Systems
* Author(s)      : Andrei Solodovnikov
* Email(s)       : hepoh@org.miet.ru
* Modified : UART test with 8N1, unit counting task
* ------------------------------------------------------------------------------
*/
module lab_13_tb_processor_system();

import peripheral_pkg::*;

parameter real CLK_FREQ   = 100_000_000.0;   // 100 МГц
parameter integer BAUD    = 9600;            // скорость, как в main.c
parameter integer BIT_T   = int'(CLK_FREQ / BAUD); // тактов на бит (~10417)

logic        clk_i;
logic        resetn;
logic        rx_i;         // UART RX (на вход процессора)
logic        tx_o;         // UART TX (от процессора)

logic [15:0] sw_i;
logic [15:0] led_o;
logic        ps2_clk;
logic        ps2_dat;
logic [6:0]  hex_led_o;
logic [7:0]  hex_sel_o;

// Тактовый генератор 100 МГц (период 10 нс)
initial clk_i = 0;
always #5ns clk_i = ~clk_i;

// Ограничение времени симуляции
initial #20ms $finish();

// Сброс
initial begin
    resetn = 1;
    repeat(20) @(posedge clk_i);
    resetn = 0;
    repeat(20) @(posedge clk_i);
    resetn = 1;
end

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


// Отправка байта в формате 8N1 (1 старт, 8 данных, 1 стоп)
task automatic send_byte_8n1(input logic [7:0] data, ref logic line);
    begin
        line = 1'b0;                // старт-бит
        #(BIT_T);
        for (int i = 0; i < 8; i++) begin
            line = data[i];         // LSB first
            #(BIT_T);
        end
        line = 1'b1;                // стоп-бит
        #(BIT_T);
    end
endtask

// Приём байта от процессора (ожидание ответа)
task automatic recv_byte_8n1(output logic [7:0] data, input logic line);
    begin
        @(negedge line);            // ждём старт-бит
        #(BIT_T/2);                // смещаемся к середине первого бита
        for (int i = 0; i < 8; i++) begin
            #(BIT_T);
            data[i] = line;
        end
        #(BIT_T);                   // пропускаем стоп-бит
    end
endtask

initial begin : test_sequence
    // Ждём снятия сброса и инициализации процессора
    wait(resetn == 1);
    #1ms;   // пауза, чтобы UART в процессоре настроился

    $display("[%0t] Test 1: send 0x5B, expect 0x1F", $time);
    rx_i = 1'b1;
    send_byte_8n1(8'h5B, rx_i);
    begin
        automatic logic [7:0] result;
        recv_byte_8n1(result, tx_o);
        $display("[%0t] Received: 0x%02h", $time, result);
        if (result == 8'h1F)
            $display("[%0t] Test 1 PASS", $time);
        else
            $error("[%0t] Test 1 FAIL: expected 0x1F, got 0x%02h", $time, result);
    end
    #100us;

    $display("[%0t] Test 2: send 0xFF, expect 0xFF", $time);
    send_byte_8n1(8'hFF, rx_i);
    begin
        automatic logic [7:0] result;
        recv_byte_8n1(result, tx_o);
        $display("[%0t] Received: 0x%02h", $time, result);
        if (result == 8'hFF)
            $display("[%0t] Test 2 PASS", $time);
        else
            $error("[%0t] Test 2 FAIL: expected 0xFF, got 0x%02h", $time, result);
    end
    #100us;

    $display("[%0t] Test 3: send 0x00, expect 0x00", $time);
    send_byte_8n1(8'h00, rx_i);
    begin
        automatic logic [7:0] result;
        recv_byte_8n1(result, tx_o);
        $display("[%0t] Received: 0x%02h", $time, result);
        if (result == 8'h00)
            $display("[%0t] Test 3 PASS", $time);
        else
            $error("[%0t] Test 3 FAIL: expected 0x00, got 0x%02h", $time, result);
    end
    #100us;

    $display("[%0t] Test 4: send 0xA5, expect 0x0F", $time);
    send_byte_8n1(8'hA5, rx_i);
    begin
        automatic logic [7:0] result;
        recv_byte_8n1(result, tx_o);
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

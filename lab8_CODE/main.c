#include <stdint.h>
#include "platform.h" // В нём объявлены структуры и указатели для доступа к периферийным устройствам


// volatile - не оптимизировать доступ к этой переменной - значение может измениться извне (из обработчика прерывания). Должны быть доступны и в main и в int_handler (не кэшировать)

volatile uint8_t  uart_byte = 0; // хранит последний принятый байт от UART
volatile int byte_ready = 0; // флаг, показывающий, что новый байт принят и готов к обработке.

void int_handler()
{
    // чтение байта из UART
    if (rx_ptr->unread_data)
    {
        uart_byte = (uint8_t)(rx_ptr->data & 0xFF); // пришедший байт лежит в малдших 8 битах и чистим их
        byte_ready = 1; // данные готовы
        rx_ptr->rst = 0;           // сброс флага прерывания
    }
}


int main()
{

    rx_ptr->baudrate = 9600;
    rx_ptr->parity_bit = 0;        // нет проверки
    rx_ptr->stop_bit = 0;       // 1 стоп бит
    rx_ptr->rst = 0;


    tx_ptr->baudrate = 9600;
    tx_ptr->parity_bit = 0;
    tx_ptr->stop_bit = 0;
    tx_ptr->rst = 0;

    while (1)
    {
        if (byte_ready)
        {
            uint8_t x = uart_byte;
            byte_ready = 0; // чтобы не обрабатывать один и тот же байт

            int count = 0;
            while (x)
            {
                count += x & 1; // выделяем младший бит (0 или 1) и добавляем к счётчику
                x >>= 1; // сдвигаем число вправо (следующий бит становится младшим)
            }

            uint8_t result;
            if (count == 0)
                result = 0;
            else
                result = (uint8_t)((1u << count) - 1); // 1u — беззнаковая единица, чтобы сдвиг работал корректно.

            while (tx_ptr->busy) {}    // busy показывает, что предыдущая передача ещё не завершена  
            tx_ptr->data = result;   // Записываем байт в регистр данных передатчика
        }
    }

    return 0;
}

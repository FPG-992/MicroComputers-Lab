#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#define DS1820_PIN PD4


uint8_t one_wire_reset(void){
    uint8_t presence;
    DDRD |= (1<<DS1820_PIN);
    PORTD &= ~(1<<DS1820_PIN);
    _delay_us(480);

    DDRD &= ~(1<<DS1820_PIN);
    _delay_us(100);

    presence = PIND & (1<<DS1820_PIN);

    _delay_us(380);

    return (presence==0);
}

uint8_t one_wire_receive_bit(void){
    uint8_t bit = 0;
    DDRD |= (1<<DS1820_PIN);
    PORTD &= ~(1<<DS1820_PIN);
    _delay_us(2);

    DDRD &= ~(1<<DS1820_PIN);
    _delay_us(10);

    if (PIND & (1<<DS1820_PIN)){
        bit = 1;
    } else {
        bit = 0;
    }

    _delay_us(49);

    return bit;
}

void one_wire_transmit_bit(uint8_t bit){
    DDRD |= (1<<DS1820_PIN);
    PORTD &= ~(1<<DS1820_PIN);
    _delay_us(2);

    if(bit & 0x01){
        PORTD |= (1<<DS1820_PIN);      
    }else {
        PORTD &= ~(1<<DS1820_PIN);
    }

    _delay_us(58);

    DDRD &= ~(1<<DS1820_PIN);
    _delay_us(1);
}

uint8_t one_wire_receive_byte(void){
    uint8_t data=0;

    for(uint8_t i=0; i<8; i++){
        uint8_t bit = one_wire_receive_bit();
        data >>= 1;
        if (bit) {
            data |= 0x80;
        }
    }
    return data;
}

void one_wire_transmit_byte(uint8_t data){
    for (uint8_t i=0; i<8; i++){
        uint8_t bit = data & 0x01;
        one_wire_transmit_bit(bit);
        data >>= 1;
    }
}

uint16_t read_temperature(void) {
    if (!one_wire_reset()) {
        return 0x8000;
    }

    one_wire_transmit_byte(0xCC);

    one_wire_transmit_byte(0x44);

    uint16_t timeout = 750; 
    while (!one_wire_receive_bit()) {
        _delay_ms(1);
        if (--timeout == 0) {
            return 0x8000;
        }
    }

    if (!one_wire_reset()) {
        return 0x8000; 
    }

    one_wire_transmit_byte(0xCC);

    one_wire_transmit_byte(0xBE);

    uint8_t temp_lsb = one_wire_receive_byte();
    uint8_t temp_msb = one_wire_receive_byte();

    int16_t temperature = (temp_msb << 8) | temp_lsb;

    return temperature;
}

int main(void) {
    DDRD = 0xFF;
    PORTD = 0x00;

    while (1) {
        uint16_t temperature = read_temperature();
        if (temperature == 0x8000) {
            PORTD = 0x00;
        } else {
            PORTD = 0xFF;
        }
        _delay_ms(1000);
    }
}
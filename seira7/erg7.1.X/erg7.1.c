#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

// Returns 1 if device is detected, 0 if no.
uint8_t one_wire_reset() {
    DDRD |= 1<<4;
    PORTD = 0;
    
    _delay_us(480);

    DDRD = 0;
    PORTD = 0;
    
    _delay_us(100);
    
    uint8_t temp = PIND;
    
    _delay_us(380);
    
    return temp ? 0 : 1;
}

uint8_t one_wire_receive_bit() {
    DDRD |= 1<<4;
    PORTD = 0;
    
    _delay_us(2);
    
    DDRD = 0;
    PORTD = 0;
    
    _delay_us(10);
    
    uint8_t temp = PIND ? 1 : 0;
    
    _delay_us(49);
    
    return temp;
}

void one_wire_transmit_bit(uint8_t bit) {
    DDRD |= 1<<4;
    PORTD = 0;
    
    _delay_us(2);
    
    PORTD = bit<<4;
    
    _delay_us(58);
    
    DDRD = 0;
    PORTD = 0;
    
    _delay_us(1);
}

uint8_t one_wire_receive_byte() {
    uint8_t output = 0x00;
    
    for (uint8_t i = 0; i < 8; i++) {
        output = output>>1;
        if (one_wire_receive_bit()) {
            output |= 1<<7;
        }
    }
    
    return output;
}

void one_wire_transmit_byte(uint8_t byte) {
    uint8_t temp = 1;
    for (uint8_t i = 0; i < 8; i++) {
        if (byte & temp) {
            one_wire_transmit_bit(1);
        } else {
            one_wire_transmit_bit(0);
        }
        temp = temp << 1;
    }
}

uint16_t temp() {
    if (!one_wire_reset()) {
        return 0x8000;
    }
    
    one_wire_transmit_byte(0xCC);
    
    one_wire_transmit_byte(0x44);
    
    while (one_wire_receive_bit());
    
    if (!one_wire_reset()) {
        return 0x8000;
    }
    
    one_wire_transmit_byte(0xCC);
    
    one_wire_transmit_byte(0xBE);
    
    uint16_t output = one_wire_receive_byte()<<8;
    output |= one_wire_receive_byte();
    
    return output;
}
